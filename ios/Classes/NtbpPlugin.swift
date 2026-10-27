import Flutter
import UIKit
import CoreBluetooth

/// NTBP plugin, iOS side.
///
/// Transport only: BLE discovery, connection and byte transfer go through the
/// Xprinter PrinterSDK (`XBLEManager`), plus the printer status query. Label
/// layouts are rendered to TSPL in Dart and arrive here as raw bytes via
/// `sendProtocolCommands`.
public class NtbpPlugin: NSObject, FlutterPlugin, XBLEManagerDelegate {

    private static let scanWindow: TimeInterval = 10.0
    private static let connectTimeout: TimeInterval = 20.0
    private static let writeTimeout: TimeInterval = 30.0

    private var ble: XBLEManager { return XBLEManager.sharedInstance() }

    private var peripherals: [String: CBPeripheral] = [:]
    private var rssiByAddress: [String: Int] = [:]
    private var pendingScan: FlutterResult?
    private var scanWorkItem: DispatchWorkItem?
    private var bluetoothState: Int = CBManagerState.unknown.rawValue

    private var pendingConnect: FlutterResult?
    private var connectWorkItem: DispatchWorkItem?
    private var connectingAddress: String?
    private var connectedAddress: String?
    private var connectedName: String?
    private var lastError: String?

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ntbp_plugin", binaryMessenger: registrar.messenger())
        let instance = NtbpPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public override init() {
        super.init()
        ble.delegate = self
    }

    deinit {
        ble.removeDelegate(self)
    }

    // MARK: - Method dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        // --- Bluetooth -----------------------------------------------------
        case "isBluetoothAvailable":
            result(isBluetoothAvailable())
        case "requestBluetoothPermissions":
            // iOS shows the permission prompt on first CoreBluetooth use.
            result(bluetoothState != CBManagerState.unauthorized.rawValue)
        case "checkDevicePairingStatus":
            // BLE peripherals do not expose bond state; pairing happens on
            // demand when a protected characteristic is accessed.
            result("NOT_REQUIRED")
        case "requestDevicePairing", "requestDevicePairingWithPin":
            result("NOT_REQUIRED")
        case "getStoredPinCode":
            result(nil)
        case "removeStoredPinCode":
            result(true)

        case "startScan":
            startScan(result: result)
        case "stopScan":
            stopScan()
            result(nil)
        case "getDiscoveredDevices":
            result(discoveredDeviceMaps())

        case "connectToDevice":
            guard let address = args["address"] as? String, !address.isEmpty else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Device address is required", details: nil))
                return
            }
            connect(address: address, name: args["name"] as? String, result: result)
        case "disconnect":
            disconnect()
            result(true)
        case "isConnected":
            result(isConnected)
        case "getConnectionStatus":
            result(connectionState)
        case "getDetailedConnectionStatus":
            result([
                "connectionState": connectionState,
                "socketConnected": isConnected,
                "hasOutputStream": isConnected,
                "socketAddress": connectedAddress as Any,
                "socketName": connectedName as Any,
                "lastError": lastError as Any,
                "bluetoothState": bluetoothState,
                "transport": "xprinter-sdk-ble",
            ])

        // --- Raw transport and status --------------------------------------
        case "sendProtocolCommands":
            // Dart sends a Uint8List (arrives as FlutterStandardTypedData);
            // older callers may send a plain List<int>.
            let payload: Data
            if let typed = args["commands"] as? FlutterStandardTypedData {
                payload = typed.data
            } else if let ints = args["commands"] as? [Int] {
                payload = Data(ints.map { UInt8(truncatingIfNeeded: $0) })
            } else if let numbers = args["commands"] as? [NSNumber] {
                payload = Data(numbers.map { UInt8(truncatingIfNeeded: $0.intValue) })
            } else {
                payload = Data()
            }
            if payload.isEmpty {
                result(FlutterError(code: "EMPTY_PAYLOAD", message: "No command bytes received", details: nil))
            } else {
                send(payload, result: result)
            }
        case "queryPrinterStatus":
            let timeoutMs = args["timeoutMs"] as? Int ?? 2000
            queryPrinterStatus(timeoutMs: timeoutMs, result: result)
        case "initializeProtocolPrinter":
            let w = (args["labelWidth"] as? NSNumber)?.doubleValue ?? 100
            let h = (args["labelHeight"] as? NSNumber)?.doubleValue ?? 150
            let unit = (args["unit"] as? String ?? "mm").lowercased()
            let size = unit == "inch" ? "SIZE \(w),\(h)" : "SIZE \(w) mm,\(h) mm"
            send(script: "\(size)\r\nGAP 3 mm,0 mm\r\nCLS\r\n", result: result)

        // --- Simple legacy prints (TSPL built here) --------------------------
        case "clearBuffer", "clearPrintBuffer":
            send(script: "CLS\r\n", result: result)
        case "feedPaper":
            let dots = min(max(args["lines"] as? Int ?? 1, 1), 9999)
            send(script: "FEED \(dots)\r\n", result: result)
        case "printText":
            let text = NtbpPlugin.tsplEscape(args["text"] as? String ?? "")
            send(script: "TEXT 50,50,\"3\",0,1,1,\"\(text)\"\r\nPRINT 1,1\r\n", result: result)
        case "printBarcode":
            let data = NtbpPlugin.tsplEscape(args["data"] as? String ?? "")
            send(script: "BARCODE 50,100,\"128\",80,1,0,2,2,\"\(data)\"\r\nPRINT 1,1\r\n", result: result)
        case "printQRCode":
            let data = NtbpPlugin.tsplEscape(args["data"] as? String ?? "")
            send(script: "QRCODE 50,50,M,6,A,0,\"\(data)\"\r\nPRINT 1,1\r\n", result: result)
        case "print":
            let commands = args["commands"] as? [[String: Any]] ?? []
            var script = "CLS\r\n"
            for cmd in commands {
                let x = (cmd["x"] as? NSNumber)?.intValue ?? 50
                let y = (cmd["y"] as? NSNumber)?.intValue ?? 50
                if cmd["isBarcode"] as? Bool == true {
                    let data = NtbpPlugin.tsplEscape(cmd["barcodeData"] as? String ?? "")
                    script += "BARCODE \(x),\(y),\"128\",80,1,0,2,2,\"\(data)\"\r\n"
                } else if cmd["isQRCode"] as? Bool == true {
                    let data = NtbpPlugin.tsplEscape(cmd["barcodeData"] as? String ?? "")
                    script += "QRCODE \(x),\(y),M,6,A,0,\"\(data)\"\r\n"
                } else if let text = cmd["text"] as? String, !text.isEmpty {
                    let font = (cmd["fontNumber"] as? NSNumber)?.stringValue ?? "3"
                    script += "TEXT \(x),\(y),\"\(font)\",0,1,1,\"\(NtbpPlugin.tsplEscape(text))\"\r\n"
                }
            }
            script += "PRINT 1,1\r\n"
            send(script: script, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Bluetooth state and discovery

    private func isBluetoothAvailable() -> Bool {
        switch bluetoothState {
        case CBManagerState.poweredOff.rawValue,
             CBManagerState.unsupported.rawValue,
             CBManagerState.unauthorized.rawValue:
            return false
        default:
            return true
        }
    }

    private func startScan(result: @escaping FlutterResult) {
        finishScan()
        peripherals.removeAll()
        rssiByAddress.removeAll()

        // Keep the connected printer listed so the UI can show it.
        if let p = ble.writePeripheral, isConnected {
            let address = p.identifier.uuidString
            peripherals[address] = p
        }

        pendingScan = result
        ble.startScan()

        let work = DispatchWorkItem { [weak self] in self?.finishScan() }
        scanWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NtbpPlugin.scanWindow, execute: work)
    }

    private func finishScan() {
        scanWorkItem?.cancel()
        scanWorkItem = nil
        if ble.isScaning { ble.stopScan() }
        guard let pending = pendingScan else { return }
        pendingScan = nil
        pending(peripherals.count)
    }

    private func stopScan() {
        finishScan()
    }

    private func discoveredDeviceMaps() -> [[String: Any]] {
        return peripherals.map { (address, peripheral) in
            return [
                "name": peripheral.name ?? "Unknown Device",
                "address": address,
                "isConnected": isConnected && connectedAddress == address,
                "rssi": rssiByAddress[address] ?? 0,
                "deviceClass": "BLE",
            ]
        }
    }

    // MARK: - Connection

    private var isConnected: Bool { return ble.isConnected }

    private var connectionState: String {
        if isConnected { return "CONNECTED" }
        if pendingConnect != nil { return "CONNECTING" }
        return "DISCONNECTED"
    }

    private func connect(address: String, name: String?, result: @escaping FlutterResult) {
        finishScan()

        guard let peripheral = peripherals[address] else {
            result(FlutterError(code: "DEVICE_NOT_FOUND",
                                message: "Device \(address) was not seen in the last scan. Scan again.",
                                details: nil))
            return
        }

        if let pending = pendingConnect {
            pendingConnect = nil
            connectWorkItem?.cancel()
            pending(FlutterError(code: "CONNECTION_CANCELLED", message: "Superseded by a new connect", details: nil))
        }
        if isConnected { ble.disconnectRootPeripheral() }

        pendingConnect = result
        connectingAddress = address
        connectedName = name ?? peripheral.name
        lastError = nil

        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let pending = self.pendingConnect else { return }
            self.pendingConnect = nil
            self.connectingAddress = nil
            self.ble.disconnectRootPeripheral()
            pending(FlutterError(code: "CONNECTION_TIMEOUT", message: "Timed out connecting to \(address)", details: nil))
        }
        connectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NtbpPlugin.connectTimeout, execute: work)

        ble.connectDevice(peripheral)
    }

    private func disconnect() {
        connectWorkItem?.cancel()
        if let pending = pendingConnect {
            pendingConnect = nil
            pending(FlutterError(code: "CONNECTION_CANCELLED", message: "Disconnected", details: nil))
        }
        if isConnected { ble.disconnectRootPeripheral() }
        connectedAddress = nil
        connectingAddress = nil
    }

    // MARK: - Data transfer and status

    private func send(script: String, result: @escaping FlutterResult) {
        send(Data(script.utf8), result: result)
    }

    private func send(_ data: Data, result: @escaping FlutterResult) {
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        guard !data.isEmpty else {
            result(FlutterError(code: "EMPTY_PAYLOAD", message: "Nothing to send", details: nil))
            return
        }

        var replied = false
        let reply: (Any?) -> Void = { value in
            if replied { return }
            replied = true
            result(value)
        }

        ble.writeCommand(with: data, writeCallBack: { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error.localizedDescription
                    reply(FlutterError(code: "SEND_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    reply(true)
                }
            }
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + NtbpPlugin.writeTimeout) {
            reply(FlutterError(code: "SEND_TIMEOUT", message: "Timed out sending \(data.count) bytes", details: nil))
        }
    }

    /// Status byte as defined by TSPL `ESC ! ?`: 0 ready, bit0 head open,
    /// bit1 paper jam, bit2 out of paper, bit3 out of ribbon, bit4 paused,
    /// bit5 printing. -1 when the printer does not answer, -2 when not
    /// connected.
    private func queryPrinterStatus(timeoutMs: Int, result: @escaping FlutterResult) {
        guard isConnected else {
            result(-2)
            return
        }
        var replied = false
        let reply: (Int) -> Void = { code in
            if replied { return }
            replied = true
            result(code)
        }

        ble.printerLabelStatus { data in
            DispatchQueue.main.async {
                guard let data = data, !data.isEmpty else {
                    reply(-1)
                    return
                }
                // The printer answers with one byte, or two where the first is
                // a header. The status is always the last byte.
                reply(Int(data[data.count - 1]))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeoutMs) / 1000.0 + 0.5) {
            reply(-1)
        }
    }

    private static func tsplEscape(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    // MARK: - XBLEManagerDelegate

    public func xbleCentralManagerDidUpdateState(_ state: Int) {
        bluetoothState = state
        // A scan requested before Bluetooth was ready: start it now.
        if state == CBManagerState.poweredOn.rawValue, pendingScan != nil, !ble.isScaning {
            ble.startScan()
        }
    }

    public func xbleDiscover(_ peripheral: CBPeripheral!, advertisementData: [AnyHashable: Any]!, rssi RSSI: NSNumber!) {
        guard let peripheral = peripheral else { return }
        let address = peripheral.identifier.uuidString
        peripherals[address] = peripheral
        if let rssi = RSSI { rssiByAddress[address] = rssi.intValue }
    }

    public func xbleConnect(_ peripheral: CBPeripheral!) {
        connectWorkItem?.cancel()
        connectWorkItem = nil
        connectedAddress = peripheral?.identifier.uuidString ?? connectingAddress
        connectingAddress = nil
        if connectedName == nil { connectedName = peripheral?.name }
        if let pending = pendingConnect {
            pendingConnect = nil
            pending(true)
        }
    }

    public func xbleFail(toConnect peripheral: CBPeripheral!, error: Error!) {
        connectWorkItem?.cancel()
        connectWorkItem = nil
        lastError = error?.localizedDescription ?? "Connection failed"
        connectingAddress = nil
        if let pending = pendingConnect {
            pendingConnect = nil
            pending(FlutterError(code: "CONNECTION_ERROR", message: "Failed to connect: \(lastError!)", details: nil))
        }
    }

    public func xbleDisconnectPeripheral(_ peripheral: CBPeripheral!, error: Error!) {
        if let error = error { lastError = error.localizedDescription }
        connectedAddress = nil
        if let pending = pendingConnect {
            connectWorkItem?.cancel()
            pendingConnect = nil
            connectingAddress = nil
            pending(FlutterError(code: "CONNECTION_ERROR",
                                 message: "Disconnected: \(error?.localizedDescription ?? "unknown")",
                                 details: nil))
        }
    }

    public func xbleWriteValue(for characteristic: CBCharacteristic!, error: Error!) {
        if let error = error { lastError = error.localizedDescription }
    }

    public func xbleReceiveValue(for characteristic: CBCharacteristic!, error: Error!) {
        // Status replies are delivered through the printerLabelStatus block.
    }
}
