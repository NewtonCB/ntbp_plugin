import Flutter
import UIKit
import CoreBluetooth
import Foundation

public class NtbpPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Properties
    
    private var methodChannel: FlutterMethodChannel?
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?
    
    // Connection state
    private var isConnected = false
    private var connectionState = "DISCONNECTED"
    private var lastError: String?
    private var connectedDeviceName: String?
    private var connectedDeviceAddress: String?
    
    // Bluetooth device management
    private var discoveredDevices: [BluetoothDevice] = []
    private var devicePinCodes: [String: String] = [:]
    
    // MARK: - Flutter Plugin Registration
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ntbp_plugin", binaryMessenger: registrar.messenger())
    let instance = NtbpPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
        instance.methodChannel = channel
  }
    
    // MARK: - Method Call Handler

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
        case "isBluetoothAvailable":
            isBluetoothAvailable(result: result)
            
        case "requestBluetoothPermissions":
            requestBluetoothPermissions(result: result)
            
        case "startScan":
            startScan(result: result)
            
        case "connectToDevice":
            connectToDevice(call: call, result: result)
            
        case "disconnect":
            disconnect(result: result)
            
        case "getConnectionStatus":
            getConnectionStatus(result: result)
            
        case "getDetailedConnectionStatus":
            getDetailedConnectionStatus(result: result)
            
        case "printSingleLabelWithGapDetection":
            printSingleLabelWithGapDetection(call: call, result: result)
            
        case "printMultipleLabelsWithGapDetection":
            printMultipleLabelsWithGapDetection(call: call, result: result)
            
        case "printProfessionalLabel":
            printProfessionalLabel(call: call, result: result)
            
        case "printLabelSequence":
            printLabelSequence(call: call, result: result)
            
        case "printCustomLabel":
            printCustomLabel(call: call, result: result)
            
        case "printSmartLabel":
            printSmartLabel(call: call, result: result)
            
        case "printSmartSequence":
            printSmartSequence(call: call, result: result)
            
        case "clearBuffer":
            clearBuffer(result: result)
            
        case "getPrinterStatus":
            getPrinterStatus(result: result)
            
        case "feedPaper":
            feedPaper(result: result)
            
        case "getLabelPaperConfig":
            getLabelPaperConfig(call: call, result: result)
            
        case "requestDevicePairing":
            requestDevicePairing(call: call, result: result)
            
        case "requestDevicePairingWithPin":
            requestDevicePairingWithPin(call: call, result: result)
            
        case "getStoredPinCode":
            getStoredPinCode(call: call, result: result)
            
        case "removeStoredPinCode":
            removeStoredPinCode(call: call, result: result)
            
        case "checkDevicePairingStatus":
            checkDevicePairingStatus(call: call, result: result)
            
    default:
      result(FlutterMethodNotImplemented)
    }
  }
    
    // MARK: - Bluetooth Management
    
    private func isBluetoothAvailable(result: @escaping FlutterResult) {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        
        let state = centralManager?.state ?? .unknown
        print("Checking Bluetooth availability - State: \(state.rawValue)")
        
        let isAvailable = state == .poweredOn
        result(isAvailable)
    }
    
    private func requestBluetoothPermissions(result: @escaping FlutterResult) {
        // On iOS, permissions are handled automatically by CoreBluetooth
        // We need to initialize the central manager to trigger permission requests
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        
        // Check current state
        let state = centralManager?.state ?? .unknown
        print("Requesting Bluetooth permissions - Current state: \(state.rawValue)")
        
        switch state {
        case .poweredOn:
            result(true)
        case .unauthorized:
            result(FlutterError(code: "BLUETOOTH_UNAUTHORIZED", message: "Bluetooth permission denied. Please enable in Settings > Privacy & Security > Bluetooth", details: nil))
        case .poweredOff:
            result(FlutterError(code: "BLUETOOTH_POWERED_OFF", message: "Bluetooth is powered off. Please turn on Bluetooth", details: nil))
        case .unsupported:
            result(FlutterError(code: "BLUETOOTH_UNSUPPORTED", message: "Bluetooth not supported on this device", details: nil))
        case .resetting:
            result(FlutterError(code: "BLUETOOTH_RESETTING", message: "Bluetooth is resetting, please wait", details: nil))
        case .unknown:
            // Wait for state to be determined
            result(FlutterError(code: "BLUETOOTH_UNKNOWN", message: "Bluetooth state unknown, please wait", details: nil))
        @unknown default:
            result(FlutterError(code: "BLUETOOTH_UNKNOWN", message: "Bluetooth state unknown", details: nil))
        }
    }
    
    private func startScan(result: @escaping FlutterResult) {
        // Ensure centralManager is initialized
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        
        guard let centralManager = centralManager else {
            result(FlutterError(code: "BLUETOOTH_NOT_AVAILABLE", message: "Bluetooth not available", details: nil))
            return
        }
        
        let state = centralManager.state
        print("Bluetooth state: \(state.rawValue)")
        
        // Handle different Bluetooth states
        switch state {
        case .poweredOn:
            // Bluetooth is ready, start scanning
            startScanning(result: result)
        case .poweredOff:
            result(FlutterError(code: "BLUETOOTH_POWERED_OFF", message: "Bluetooth is powered off", details: nil))
        case .unauthorized:
            result(FlutterError(code: "BLUETOOTH_UNAUTHORIZED", message: "Bluetooth permission denied", details: nil))
        case .unsupported:
            result(FlutterError(code: "BLUETOOTH_UNSUPPORTED", message: "Bluetooth not supported", details: nil))
        case .resetting:
            result(FlutterError(code: "BLUETOOTH_RESETTING", message: "Bluetooth is resetting", details: nil))
        case .unknown:
            // Wait for state to be determined
            result(FlutterError(code: "BLUETOOTH_UNKNOWN", message: "Bluetooth state unknown, please wait", details: nil))
        @unknown default:
            result(FlutterError(code: "BLUETOOTH_UNKNOWN", message: "Bluetooth state unknown", details: nil))
        }
    }
    
    private func startScanning(result: @escaping FlutterResult) {
        guard let centralManager = centralManager else { return }
        
        // Clear previous discoveries
        discoveredDevices.removeAll()
        
        print("Starting Bluetooth scan...")
        
        // Start scanning for devices
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        // Stop scanning after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            self?.centralManager?.stopScan()
            print("Stopping Bluetooth scan...")
            
            // Convert discovered devices to Flutter format
            let deviceList = self?.discoveredDevices.map { device in
                return [
                    "name": device.name,
                    "address": device.address,
                    "bondState": device.bondState,
                    "uuids": device.uuids
                ]
            } ?? []
            
            print("Found \(deviceList.count) devices")
            result(deviceList)
        }
    }
    
    private func connectToDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceData = args["device"] as? [String: Any],
              let address = deviceData["address"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid device data", details: nil))
            return
        }
        
        // Find the peripheral by address
        guard let peripheral = discoveredDevices.first(where: { $0.address == address })?.peripheral else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found", details: nil))
            return
        }
        
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        
        // Connect to the peripheral
        centralManager?.connect(peripheral, options: nil)
        
        // Update connection state
        connectionState = "CONNECTING"
        result(nil)
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        if let peripheral = peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        
        // Reset connection state
        isConnected = false
        connectionState = "DISCONNECTED"
        peripheral = nil
        writeCharacteristic = nil
        readCharacteristic = nil
        
        result(true)
    }
    
    private func getConnectionStatus(result: @escaping FlutterResult) {
        result(connectionState)
    }
    
    private func getDetailedConnectionStatus(result: @escaping FlutterResult) {
        let details: [String: Any] = [
            "status": connectionState,
            "deviceName": connectedDeviceName ?? "",
            "deviceAddress": connectedDeviceAddress ?? "",
            "peripheralConnected": peripheral != nil,
            "characteristicsAvailable": writeCharacteristic != nil,
            "lastError": lastError
        ]
        
        result(details)
    }
    
    // MARK: - Printing Methods
    
    private func printSingleLabelWithGapDetection(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        let qrData = args["qrData"] as? String ?? "QR001"
        let textData = args["textData"] as? String ?? "Sample Text"
        let width = args["width"] as? Double ?? 75.0
        let height = args["height"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        let copies = args["copies"] as? Int ?? 1
        let textSize = args["textSize"] as? Int ?? 9
        
        // Perform printing on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performSingleLabelPrint(
                qrData: qrData,
                textData: textData,
                width: width,
                height: height,
                unit: unit,
                dpi: dpi,
                copies: copies,
                textSize: textSize,
                result: result
            )
        }
    }
    
    private func printMultipleLabelsWithGapDetection(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        guard let labelDataList = args["labelDataList"] as? [[String: Any]] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid label data list", details: nil))
            return
        }
        
        let width = args["width"] as? Double ?? 75.0
        let height = args["height"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        let copiesPerLabel = args["copiesPerLabel"] as? Int ?? 1
        let textSize = args["textSize"] as? Int ?? 9
        
        // Perform printing on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performMultipleLabelsPrint(
                labelDataList: labelDataList,
                width: width,
                height: height,
                unit: unit,
                dpi: dpi,
                copiesPerLabel: copiesPerLabel,
                textSize: textSize,
                result: result
            )
        }
    }
    
    // MARK: - Buffer Management
    
    private func clearBuffer(result: @escaping FlutterResult) {
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        let commands = "CLEAR\nCLS\nHOME\n"
        sendCommands(commands) { success in
            result(success)
        }
    }
    
    private func getPrinterStatus(result: @escaping FlutterResult) {
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        // Send STATUS command and wait for response
        sendCommands("STATUS\n") { success in
            if success {
                result("READY")
            } else {
                result("ERROR")
            }
        }
    }
    
    private func feedPaper(result: @escaping FlutterResult) {
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        sendCommands("FEED\n") { success in
            result(success)
        }
    }
    
    // MARK: - Additional Printing Methods
    
    private func printProfessionalLabel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        let qrData = args["qrData"] as? String ?? "PROF001"
        let textData = args["textData"] as? String ?? "Professional Label"
        let width = args["width"] as? Double ?? 75.0
        let height = args["height"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        
        // Perform printing on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performSingleLabelPrint(
                qrData: qrData,
                textData: textData,
                width: width,
                height: height,
                unit: unit,
                dpi: dpi,
                copies: 1,
                textSize: 9,
                result: result
            )
        }
    }
    
    private func printLabelSequence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        guard let labelDataList = args["labelDataList"] as? [[String: Any]] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid label data list", details: nil))
            return
        }
        
        let width = args["width"] as? Double ?? 75.0
        let height = args["height"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        
        // Perform printing on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performMultipleLabelsPrint(
                labelDataList: labelDataList,
                width: width,
                height: height,
                unit: unit,
                dpi: dpi,
                copiesPerLabel: 1,
                textSize: 9,
                result: result
            )
        }
    }
    
    private func printCustomLabel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        let qrData = args["qrData"] as? String ?? "CUSTOM001"
        let textData = args["textData"] as? String ?? "Custom Label"
        let width = args["width"] as? Double ?? 75.0
        let height = args["height"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        let qrSize = args["qrSize"] as? Int ?? 200
        let textSize = args["textSize"] as? Int ?? 9
        
        // Perform printing on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performSingleLabelPrint(
                qrData: qrData,
                textData: textData,
                width: width,
                height: height,
                unit: unit,
                dpi: dpi,
                copies: 1,
                textSize: textSize,
                result: result
            )
        }
    }
    
    private func printSmartLabel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        let qrData = args["qrData"] as? String ?? "SMART001"
        let textData = args["textData"] as? String ?? "Smart Label"
        let labelWidth = args["labelWidth"] as? Double ?? 75.0
        let labelHeight = args["labelHeight"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        
        // Perform printing on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performSingleLabelPrint(
                qrData: qrData,
                textData: textData,
                width: labelWidth,
                height: labelHeight,
                unit: unit,
                dpi: dpi,
                copies: 1,
                textSize: 9,
                result: result
            )
        }
    }
    
    private func printSmartSequence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
            return
        }
        
        guard let labelDataList = args["labelDataList"] as? [[String: Any]] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid label data list", details: nil))
            return
        }
        
        let labelWidth = args["labelWidth"] as? Double ?? 75.0
        let labelHeight = args["labelHeight"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        
        // Perform printing on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performMultipleLabelsPrint(
                labelDataList: labelDataList,
                width: labelWidth,
                height: labelHeight,
                unit: unit,
                dpi: dpi,
                copiesPerLabel: 1,
                textSize: 9,
                result: result
            )
        }
    }
    
    // MARK: - Device Pairing Methods
    
    private func requestDevicePairing(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // On iOS, pairing is handled automatically by the system
        result(true)
    }
    
    private func requestDevicePairingWithPin(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceData = args["device"] as? [String: Any],
              let address = deviceData["address"] as? String,
              let pinCode = args["pinCode"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        // Store PIN code for the device
        devicePinCodes[address] = pinCode
        
        // On iOS, pairing with PIN is handled automatically
        result(true)
    }
    
    private func getStoredPinCode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceData = args["device"] as? [String: Any],
              let address = deviceData["address"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid device data", details: nil))
            return
        }
        
        let pinCode = devicePinCodes[address]
        result(pinCode)
    }
    
    private func removeStoredPinCode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceData = args["device"] as? [String: Any],
              let address = deviceData["address"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid device data", details: nil))
            return
        }
        
        devicePinCodes.removeValue(forKey: address)
        result(true)
    }
    
    private func checkDevicePairingStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // On iOS, we can't directly check pairing status
        // Return true as iOS handles pairing automatically
        result(true)
    }
    
    private func getLabelPaperConfig(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        let width = args["width"] as? Double ?? 75.0
        let height = args["height"] as? Double ?? 50.0
        let unit = args["unit"] as? String ?? "mm"
        let dpi = args["dpi"] as? Int ?? 203
        
        let config = calculateLabelPaperConfig(width: width, height: height, unit: unit, dpi: dpi)
        result(config)
    }
    
    private func calculateLabelPaperConfig(width: Double, height: Double, unit: String, dpi: Int) -> [String: Any] {
        let widthInDots = convertToDots(dpi: dpi, dimension: width, unit: unit)
        let heightInDots = convertToDots(dpi: dpi, dimension: height, unit: unit)
        
        let gapSize: Int
        if height <= 20 {
            gapSize = convertToDots(dpi: dpi, dimension: 2.0, unit: "mm")
        } else if height <= 40 {
            gapSize = convertToDots(dpi: dpi, dimension: 2.5, unit: "mm")
        } else {
            gapSize = convertToDots(dpi: dpi, dimension: 3.0, unit: "mm")
        }
        
        let marginInDots: Int
        if width <= 30 {
            marginInDots = convertToDots(dpi: dpi, dimension: 2.0, unit: "mm")
        } else if width <= 60 {
            marginInDots = convertToDots(dpi: dpi, dimension: 3.0, unit: "mm")
        } else {
            marginInDots = convertToDots(dpi: dpi, dimension: 4.0, unit: "mm")
        }
        
        let availableWidth = widthInDots - 2 * marginInDots
        let availableHeight = heightInDots - 2 * marginInDots
        
        let qrSize: Int
        if width <= 30 {
            qrSize = Int(Double(availableWidth) * 0.6)
        } else if width <= 60 {
            qrSize = Int(Double(availableWidth) * 0.65)
        } else {
            qrSize = Int(Double(availableWidth) * 0.7)
        }
        
        return [
            "widthInDots": widthInDots,
            "heightInDots": heightInDots,
            "gapSize": gapSize,
            "marginInDots": marginInDots,
            "availableWidth": availableWidth,
            "availableHeight": availableHeight,
            "qrSize": qrSize,
            "textSize": 9
        ]
    }
}

// MARK: - Private Helper Methods

extension NtbpPlugin {
    
    private func performSingleLabelPrint(
        qrData: String,
        textData: String,
        width: Double,
        height: Double,
        unit: String,
        dpi: Int,
        copies: Int,
        textSize: Int,
        result: @escaping FlutterResult
    ) {
        // Send gap detection commands
        sendGapDetectionCommands(width: width, height: height, unit: unit, dpi: dpi)
        Thread.sleep(forTimeInterval: 0.3)
        
        // Clear printer buffer
        sendCommands("CLS\n") { [weak self] success in
            if success {
                Thread.sleep(forTimeInterval: 0.2)
                
                // Calculate positions
                guard let positions = self?.calculatePositions(width: width, height: height, unit: unit, dpi: dpi, textSize: textSize) else {
                    result(FlutterError(code: "POSITION_CALCULATION_ERROR", message: "Failed to calculate positions", details: nil))
                    return
                }
                
                // Build TSPL commands
                let commands = self?.buildSingleLabelCommands(
                    qrData: qrData,
                    textData: textData,
                    positions: positions,
                    copies: copies
                ) ?? ""
                
                // Send commands
                self?.sendCommands(commands) { success in
                    if success {
                        Thread.sleep(forTimeInterval: TimeInterval(0.5 * Double(copies)))
                        result(true)
                    } else {
                        result(FlutterError(code: "PRINTING_ERROR", message: "Failed to print label", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "BUFFER_CLEAR_ERROR", message: "Failed to clear buffer", details: nil))
            }
        }
    }
    
    private func performMultipleLabelsPrint(
        labelDataList: [[String: Any]],
        width: Double,
        height: Double,
        unit: String,
        dpi: Int,
        copiesPerLabel: Int,
        textSize: Int,
        result: @escaping FlutterResult
    ) {
        // Send gap detection commands
        sendGapDetectionCommands(width: width, height: height, unit: unit, dpi: dpi)
        Thread.sleep(forTimeInterval: 0.3)
        
        var successCount = 0
        var failureCount = 0
        
        let group = DispatchGroup()
        
        for (index, labelData) in labelDataList.enumerated() {
            group.enter()
            
            let qrData = labelData["qrData"] as? String ?? "Label\(index + 1)"
            let textData = labelData["textData"] as? String ?? "Text\(index + 1)"
            
            // Clear printer buffer before each label
            sendCommands("CLS\n") { [weak self] success in
                if success {
                    Thread.sleep(forTimeInterval: 0.2)
                    
                    // Calculate positions
                    guard let positions = self?.calculatePositions(width: width, height: height, unit: unit, dpi: dpi, textSize: textSize) else {
                        failureCount += 1
                        group.leave()
                        return
                    }
                    
                    // Build TSPL commands
                    let commands = self?.buildSingleLabelCommands(
                        qrData: qrData,
                        textData: textData,
                        positions: positions,
                        copies: copiesPerLabel
                    ) ?? ""
                    
                    // Send commands
                    self?.sendCommands(commands) { success in
                        if success {
                            Thread.sleep(forTimeInterval: TimeInterval(0.5 * Double(copiesPerLabel)))
                            
                            // Feed to next label (except last)
                            if index < labelDataList.count - 1 {
                                self?.sendCommands("FORMFEED\n") { _ in
                                    Thread.sleep(forTimeInterval: 0.4)
                                    group.leave()
                                }
                            } else {
                                group.leave()
                            }
                            
                            successCount += 1
                        } else {
                            failureCount += 1
                            group.leave()
                        }
                    }
                } else {
                    failureCount += 1
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            // Final cut command
            self?.sendCommands("CUT\n") { _ in
                if failureCount == 0 {
                    result(true)
                } else {
                    result(false)
                }
            }
        }
    }
    
    private func sendGapDetectionCommands(width: Double, height: Double, unit: String, dpi: Int) {
        let widthInDots = convertToDots(dpi: dpi, dimension: width, unit: unit)
        let heightInDots = convertToDots(dpi: dpi, dimension: height, unit: unit)
        
        let gapSize: Int
        if height <= 20 {
            gapSize = convertToDots(dpi: dpi, dimension: 2.0, unit: "mm")
        } else if height <= 40 {
            gapSize = convertToDots(dpi: dpi, dimension: 2.5, unit: "mm")
        } else {
            gapSize = convertToDots(dpi: dpi, dimension: 3.0, unit: "mm")
        }
        
        let commands = """
        CLEAR
        SIZE \(widthInDots),\(heightInDots)
        GAP \(gapSize),0
        GAPDETECT ON
        AUTODETECT ON
        CLS
        """
        
        sendCommands(commands) { _ in }
    }
    
    private func calculatePositions(width: Double, height: Double, unit: String, dpi: Int, textSize: Int) -> [String: Int] {
        let widthInDots = convertToDots(dpi: dpi, dimension: width, unit: unit)
        let heightInDots = convertToDots(dpi: dpi, dimension: height, unit: unit)
        
        let marginInDots: Int
        if width <= 30 {
            marginInDots = convertToDots(dpi: dpi, dimension: 2.0, unit: "mm")
        } else if width <= 60 {
            marginInDots = convertToDots(dpi: dpi, dimension: 3.0, unit: "mm")
        } else {
            marginInDots = convertToDots(dpi: dpi, dimension: 4.0, unit: "mm")
        }
        
        let availableWidth = widthInDots - 2 * marginInDots
        let availableHeight = heightInDots - 2 * marginInDots
        
        let qrSize: Int
        if width <= 30 {
            qrSize = Int(Double(availableWidth) * 0.6)
        } else if width <= 60 {
            qrSize = Int(Double(availableWidth) * 0.65)
        } else {
            qrSize = Int(Double(availableWidth) * 0.7)
        }
        
        let qrX = marginInDots + (availableWidth - qrSize) / 2
        let qrY = marginInDots + Int(Double(availableHeight) * 0.15)
        let textX = marginInDots + (availableWidth - convertToDots(dpi: dpi, dimension: 20.0, unit: "mm")) / 2
        let textY = qrY + qrSize + convertToDots(dpi: dpi, dimension: 8.0, unit: "mm")
        
        return [
            "qrX": qrX,
            "qrY": qrY,
            "qrSize": qrSize,
            "textX": textX,
            "textY": textY
        ]
    }
    
    private func buildSingleLabelCommands(qrData: String, textData: String, positions: [String: Int], copies: Int) -> String {
        let qrX = positions["qrX"] ?? 0
        let qrY = positions["qrY"] ?? 0
        let qrSize = positions["qrSize"] ?? 200
        let textX = positions["textX"] ?? 0
        let textY = positions["textY"] ?? 0
        
        return """
        REFERENCE 0,0
        DIRECTION 0
        QRCODE \(qrX),\(qrY),H,10,A,0,"\(qrData)"
        TEXT \(textX),\(textY),"9",0,1,1,"\(textData)"
        PRINT \(copies)
        """
    }
    
    private func convertToDots(dpi: Int, dimension: Double, unit: String) -> Int {
        switch unit.lowercased() {
        case "mm":
            return Int(dimension * Double(dpi) / 25.4)
        case "inch":
            return Int(dimension * Double(dpi))
        case "dot":
            return Int(dimension)
        default:
            return Int(dimension * Double(dpi) / 25.4)
        }
    }
    

    
    private func sendCommands(_ commands: String, completion: @escaping (Bool) -> Void) {
        guard let writeCharacteristic = writeCharacteristic,
              let peripheral = peripheral else {
            completion(false)
            return
        }
        
        guard let data = commands.data(using: .utf8) else {
            completion(false)
            return
        }
        
        peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
        completion(true)
    }
}

// MARK: - CBCentralManagerDelegate

extension NtbpPlugin: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Bluetooth state changed to: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on and ready")
        case .poweredOff:
            print("❌ Bluetooth is powered off")
        case .unsupported:
            print("❌ Bluetooth is not supported on this device")
        case .unauthorized:
            print("❌ Bluetooth permission denied - check Settings > Privacy & Security > Bluetooth")
        case .resetting:
            print("⏳ Bluetooth is resetting, please wait")
        case .unknown:
            print("❓ Bluetooth state is unknown")
        @unknown default:
            print("❓ Bluetooth state is unknown")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown Device"
        let deviceAddress = peripheral.identifier.uuidString
        
        print("Discovered device: \(deviceName) (\(deviceAddress))")
        print("RSSI: \(RSSI)")
        print("Advertisement data: \(advertisementData)")
        
        let device = BluetoothDevice(
            name: deviceName,
            address: deviceAddress,
            bondState: 0, // iOS doesn't provide bond state
            uuids: [],
            peripheral: peripheral
        )
        
        if !discoveredDevices.contains(where: { $0.address == device.address }) {
            discoveredDevices.append(device)
            print("Added device to discovered list. Total devices: \(discoveredDevices.count)")
        } else {
            print("Device already in list")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        
        self.peripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        connectionState = "CONNECTED"
        isConnected = true
        connectedDeviceName = peripheral.name
        connectedDeviceAddress = peripheral.identifier.uuidString
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(peripheral.name ?? "Unknown")")
        
        connectionState = "ERROR"
        lastError = error?.localizedDescription
        isConnected = false
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
        
        connectionState = "DISCONNECTED"
        isConnected = false
        self.peripheral = nil
        writeCharacteristic = nil
        readCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate

extension NtbpPlugin: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
            }
            
            if characteristic.properties.contains(.notify) {
                readCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value: \(error.localizedDescription)")
        } else {
            print("Successfully wrote value to characteristic")
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value: \(error.localizedDescription)")
        } else {
            if let data = characteristic.value,
               let response = String(data: data, encoding: .utf8) {
                print("Received response: \(response)")
            }
        }
    }
}

// MARK: - BluetoothDevice Model

struct BluetoothDevice {
    let name: String
    let address: String
    let bondState: Int
    let uuids: [Int]
    let peripheral: CBPeripheral
} 