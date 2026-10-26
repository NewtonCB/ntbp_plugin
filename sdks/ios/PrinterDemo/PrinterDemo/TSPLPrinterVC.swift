//
//  TSPLPrinterVC.swift
//  PrinterDemo
//
//  Created by Apple Mac mini intel on 2024/12/23.
//

import UIKit

class TSPLPrinterVC: UIViewController {
    
    // Bluetooth manager
    var bleManager: XBLEManager!
    // WiFi manager
    var wifiManager: XWIFIManager!
    
    var connectType: Int = 0
    
    @IBOutlet weak var cutterModeSegControl: UISegmentedControl!
    var cutter: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "TSPL PRINT"
        cutter = 0
        bleManager = XBLEManager.sharedInstance()
        bleManager.delegate = self
        wifiManager = XWIFIManager.sharedInstance()
        wifiManager.delegate = self
    }
    
    deinit {
        bleManager.removeDelegate(self)
        wifiManager.removeDelegate(self)
    }
    
    func printWithData(_ data: Data) {
        
        switch ConnectType(rawValue: connectType) {
        case .bluetooth:
            bleManager.writeCommand(with: data, writeCallBack: { characteristic, error in
                if let error = error {
                    print("error: \(error)")
                } else {
                    print("write success")
                }
            })
        case .wifi:
            wifiManager.writeCommand(with: data, writeCallBack: { success, error in
                if let error = error {
                    print("error: \(error)")
                } else {
                    print("write success")
                }
            })
        case .mfi:
            XAccessory.sharedInstance().write(data)
        default:
            self.view.makeToast("printer no connect", duration: 1.0, position: .center)
        }
    }

    @IBAction func printTextAction(_ sender: Any) {
        let command = XTSPLCommand()
            .sizeMm(70, height: 85)
            .gapMm(2, n: 0)
            .cls()
            .textAt(x: 0, y: 50, font: kFNT_8_12, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_8_12")
            .textAt(x: 0, y: 100, font: kFNT_12_20, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_12_20")
            .textAt(x: 0, y: 150, font: kFNT_16_24, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_16_24")
            .textAt(x: 0, y: 200, font: kFNT_24_32, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_24_32")
            .textAt(x: 0, y: 250, font: kFNT_32_48, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_32_48")
            .textAt(x: 0, y: 300, font: kFNT_14_19, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_14_19")
            .textAt(x: 0, y: 350, font: kFNT_14_25, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_14_25")
            .textAt(x: 0, y: 400, font: kFNT_21_27, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_21_27")
        
            // TODO: Please confirm whether the printer has built-in simplified Chinese/traditional Chinese/Korean fonts
            // .textAt(x: 0, y: 450, font: kFNT_SIMPLIFIED_CHINESE, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_SIMPLIFIED_CHINESE")
            // .textAt(x: 0, y: 500, font: kFNT_TRADITIONAL_CHINESE, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_TRADITIONAL_CHINESE")
            // .textAt(x: 0, y: 550, font: kFNT_KOREAN, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "kFNT_KOREAN")
        
            .print()
        printWithData(command!.getCommand())
    }
    
    @IBAction func printBarcodeAction(_ sender: Any) {
        
        let command = XTSPLCommand()
            .sizeMm(70, height: 85)
            .gapMm(2, n: 0)
            .cls()
            .barcodeAt(x: 0, y: 100, codeType: kBarcodeTypeCode128, height: 80, readable: ReadableType.center, andRotation: TSPLRotation.rotation0, narrow: 2, wide: 2, content: "12345678")
            .barcodeAt(x: 200, y: 100, codeType: kBarcodeTypeCode128Manual, height: 80, readable: ReadableType.center, andRotation: TSPLRotation.rotation0, narrow: 2, wide: 2, content: "12345678")
            .barcodeAt(x: 0, y: 260, codeType: kBarcodeTypeEAN128, height: 80, readable: ReadableType.center, andRotation: TSPLRotation.rotation0, narrow: 2, wide: 2, content: "12345678")
            .barcodeAt(x: 200, y: 260, codeType: kBarcodeTypeInterleaved25, height: 80, readable: ReadableType.center, andRotation: TSPLRotation.rotation0, narrow: 2, wide: 2, content: "12345678")
            .print()
        printWithData(command!.getCommand())
    }
    
    @IBAction func printQrcodeAction(_ sender: Any) {
        let command = XTSPLCommand()
            .sizeMm(70, height: 85)
            .gapMm(2, n: 0)
            .cls()
            .textAt(x: 10, y: 0, font: kFNT_12_20, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "QRCode")
            .qrCodeAt(x: 200, andY: 10, ecLevel: kECLevelM, cellWidth: 8, mode: kQRCodeModeAuto, rotation: TSPLRotation.rotation0, content: "www.google.com")
            .textAt(x: 10, y: 200, font: kFNT_12_20, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "PDF417")
            .pdf417At(x: 200, y: 200, width: 80, height: 80, rotate: TSPLRotation.rotation0, content: "PDF417")
            .textAt(x: 10, y: 300, font: kFNT_12_20, rotation: TSPLRotation.rotation0, xRatio: 1, yRatio: 1, content: "DataMatrix")
            .dataMatrixAt(x: 200, andY: 300, width: 80, height: 80, content: "DataMatrix")
            .print()
        printWithData(command!.getCommand())
    }
    
    @IBAction func printImageAction(_ sender: Any) {

        if let image = UIImage(named: "image") {
            let command = XTSPLCommand()
                .sizeMm(70, height: 85)
                .gapMm(2, n: 0)
                .cls()
                .bitmapAt(x: 0, y: 0, mode: BMPMode.overwrite, image: image)
                .print()
            printWithData(command!.getCommand())
        }
        
    }
    
    @IBAction func printerStatusAction(_ sender: Any) {
        if connectType == ConnectType.bluetooth.rawValue {
            bleManager.printerLabelStatus { [weak self] statusData in
                guard let self = self else { return }
                self.toast(with: statusData!)
            }
        } else if connectType == ConnectType.wifi.rawValue {
            wifiManager.printerLabelStatus { [weak self] statusData in
                guard let self = self else { return }
                self.toast(with: statusData!)
            }
        } else if connectType == ConnectType.mfi.rawValue {
        
        }
    }
    
    func toast(with data: Data) {
        var status: UInt8 = 0

        if data.count == 1 {
            status = data[0]
        } else if data.count == 2 {
            status = data[1]
        }

        let message: String
        switch status {
        case 0x00:
            message = "Ready"
        case 0x01:
            message = "Cover opened"
        case 0x02:
            message = "Paper jam"
        case 0x03:
            message = "Cover opened and paper jam"
        case 0x04:
            message = "Paper end"
        case 0x05:
            message = "Cover opened and Paper end"
        case 0x08:
            message = "No Ribbon"
        case 0x09:
            message = "Cover opened and no Ribbon"
        case 0x10:
            message = "Pause"
        case 0x20:
            message = "Printing.."
        default:
            return // Do nothing if the status code is unknown
        }

        self.view.makeToast(message, duration: 1.0, position: .center)
    }

}
           
// MARK: - XBLEManagerDelegate delegate

extension TSPLPrinterVC: XBLEManagerDelegate {
    
    // Connection Failed
    func xbleFail(toConnect peripheral: CBPeripheral!, error: Error!) {
        print("Failed to Connect to Peripheral: \(peripheral.name ?? "Unknown")")
        print("Error: \(error.localizedDescription)")
    }
    
    // Disconnection
    func xbleDisconnectPeripheral(_ peripheral: CBPeripheral!, error: Error!) {
        print("Disconnected from Peripheral: \(peripheral.name ?? "Unknown")")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        } else {
            print("Disconnected without error.")
        }
    }
    
    // Data Send Successful
    func xbleWriteValue(for characteristic: CBCharacteristic!, error: Error!) {
        print("Write to Characteristic: \(characteristic.uuid)")
        if let error = error {
            print("Write Error: \(error.localizedDescription)")
        } else {
            print("Write Successful")
        }
    }
    
    // Received Printer Data
    func xbleReceiveValue(for characteristic: CBCharacteristic!, error: Error!) {
        print("Received Data from Characteristic: \(characteristic.uuid)")
        if let error = error {
            print("Receive Error: \(error.localizedDescription)")
        } else if let value = characteristic.value {
            print("Received Data: \(value as NSData)")
        } else {
            print("No Data Received")
        }
    }
    
}


// MARK: - XWIFIManagerDelegate delegate

extension TSPLPrinterVC: XWIFIManagerDelegate {
    
    // Callback for disconnection error
    func xWifiDisconnectWithError(_ error: Error!) {
        print("Disconnected with Error: \(error.localizedDescription)")
    }
    
    // Callback for successful data transmission
    func xWifiWriteValue(withTag tag: Int) {
        print("Data Transmission Successful. Tag: \(tag)")
    }
    
    // Callback for receiving data from the printer
    func xWifiReceiveValue(for data: Data!) {
        print("Received Data: \(data as NSData)")
    
        // Optional: Convert data to a string for debugging, if the data is UTF-8 encoded
        if let dataString = String(data: data, encoding: .utf8) {
            print("Received Data as String: \(dataString)")
        }
    }
    
}


