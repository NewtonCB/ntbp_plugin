//
//  POSPrinterVC.swift
//  PrinterDemo
//
//  Created by Apple Mac mini intel on 2024/12/23.
//

import UIKit

class POSPrinterVC: UIViewController {
    
    // Bluetooth manager
    var bleManager: XBLEManager!
    
    // WiFi manager
    var wifiManager: XWIFIManager!
    
    // Connection type (Bluetooth or WiFi)
    var connectType: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "POS PRINT"
        bleManager = XBLEManager.sharedInstance()
        bleManager.delegate = self
        wifiManager = XWIFIManager.sharedInstance()
        wifiManager.delegate = self
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionDataReceived(_:)),
                                               name: NSNotification.Name("EADSessionDataReceivedNotification"),
                                               object: nil)

    }
    
    @objc func sessionDataReceived(_ notification: Notification) {
        guard let session = notification.object as? XAccessory else { return }

        while true {
            let bytesAvailable = session.readBytesAvailable()
            if bytesAvailable <= 0 { break } // If there is no readable data, exit the loop
            
            let data = session.readData(UInt(bytesAvailable))
            posPrinterState(data)
        }
    }

    
    deinit {
        bleManager.removeDelegate(self)
        wifiManager.removeDelegate(self)
    }
    
    @IBAction func printTextAction(_ sender: Any) {
        let command = XPOSCommand()
            .initializePrinter()
            .setHorizontalTab()
            .addText("123456789abc\n")
            .selectTextSize(Int32(TextWidth.width1.rawValue | TextHeight.height1.rawValue))
            .addText("123456789abc\n")
            .selectTextSize(Int32(TextWidth.width2.rawValue | TextHeight.height2.rawValue))
            .addText("123456789abc\n")
            .selectTextSize(Int32(TextWidth.width3.rawValue | TextHeight.height3.rawValue))
            .addText("123456789abc\n")
            .printAndFeedLines(5)
        printWithData(command.getCommand())
    }
    
    @IBAction func printBarcodeAction(_ sender: Any) {
        let command = XPOSCommand()
            .initializePrinter()
            .select(POSAlignment.center)
            .selectHRICharacterPrintPosition(0)
            .selectBarcodeHeight(70)
            .addText("UPC-A\n")
            .printBarcode(with: BarcodeType.UPCA, andContent: "123456789012")
            .lineFeed()
            .addText("JAN13\n")
            .printBarcode(with: BarcodeType.JAN13_EAN13, andContent: "123456791234")
            .lineFeed()
            .addText("JAN8\n")
            .printBarcode(with: BarcodeType.JAN8_EAN8, andContent: "12345678")
            .lineFeed()
            .addText("CODE39\n")
            .setBarcodeWidth(2)
            .printBarcode(with: BarcodeType.code39, andContent: "ABCDEFGHI")
            .lineFeed()
            .addText("ITF\n")
            .printBarcode(with: BarcodeType.ITF, andContent: "123456789012")
            .lineFeed()
            .addText("CODEBAR\n")
            .printBarcode(with: BarcodeType.codabar, andContent: "A37859B")
            .lineFeed()
            .addText("CODE93\n")
            .printBarcode(with: BarcodeType.code93, andContent: "01234567")
            .lineFeed()
            .addText("CODE128\n")
            .printBarcode(with: BarcodeType.code128, andContent: "CODE128 123456")
            .lineFeed()
            .printAndFeedLines(5)
        printWithData(command.getCommand())
    }
    
    @IBAction func printQrcodeAction(_ sender: Any) {
        let command = XPOSCommand()
            .initializePrinter()
            .select(.center)
            .printQRCode(withContent: "www.google.com", moduleSize: 6, ecLevel: QRErrorCorrectionLevel.L)
            .lineFeed()
            .printQRCode(withContent: "www.google.com", moduleSize: 8, ecLevel: QRErrorCorrectionLevel.M)
            .lineFeed()
            .printQRCode(withContent: "www.google.com", moduleSize: 12, ecLevel: QRErrorCorrectionLevel.Q)
            .lineFeed()
            .printQRCode(withContent: "www.google.com", moduleSize: 16, ecLevel: QRErrorCorrectionLevel.H)
            .printAndFeedLines(6)
            .cutPaper(with: PaperCutMode.partialCut)
        printWithData(command.getCommand())
    }
    
    @IBAction func printImageAction(_ sender: Any) {
        if let image = UIImage(named: "pos_codepage") {
            let command = XPOSCommand()
                .initializePrinter()
                .select(.left)
                .compressionPrint(image, type: BMPType.threshold, mode: BmpScaleType.normal)
                .printAndFeedLines(6)
                .cutPaper(with: .partialCut)
            
            printWithData(command.getCommand())
        }
    }
    
    @IBAction func downloadFlashAction(_ sender: Any) {
        let images: [UIImage] = [
            UIImage(named: "Logo")!,
            UIImage(named: "Rabit")!,
            UIImage(named: "JsLogo")!
        ]

        let command = XPOSCommand()
            .definedFlashBmp(withImage: images)
        
        printWithData(command.getCommand())
    }
    
    @IBAction func printFlashAction(_ sender: Any) {
        let command = XPOSCommand()
            .initializePrinter()
            .addText("FLASH Bitmap serial number 1:\n")
            .printBitmapToFlash(withN: 1, andM: 0)
            .lineFeed()
            .addText("FLASH Bitmap serial number 2:\n")
            .printBitmapToFlash(withN: 2, andM: 0)
            .lineFeed()
            .addText("FLASH Bitmap serial number 3:\n")
            .printBitmapToFlash(withN: 3, andM: 0)
            .printAndFeedLines(6)
            .cutPaper(with: .partialCut)
        printWithData(command.getCommand())
    }
    
    @IBAction func checkStatusAction(_ sender: Any) {
        
        switch ConnectType(rawValue: connectType) {
        case .bluetooth:
            bleManager.printerPOSStatus { data in
                self.posPrinterState(data)
            }
        case .wifi:
            wifiManager.printerPOSStatus { data in
                self.posPrinterState(data)
            }
        case .mfi:
            let queryArr: [UInt8] = [0x10, 0x04, 0x02]
            let queryData = Data(queryArr)
            XAccessory.sharedInstance().write(queryData)
            
        default:
            self.view.makeToast("printer no connect", duration: 1.0, position: .center)
        }
        
    }
    
    func posPrinterState(_ data: Data!) {
        var status: UInt8 = 0
        
        if data.count == 1 {
            status = data.first ?? 0
        } else if data.count == 2 {
            status = data.last ?? 0
        }
        
        switch status {
        case 0x12:
            self.view.makeToast("Normal", duration: 1.0, position: .center)
        case 0x16:
            self.view.makeToast("Cover opened", duration: 1.0, position: .center)
        case 0x32:
            self.view.makeToast("Paper end", duration: 1.0, position: .center)
        case 0x36:
            self.view.makeToast("Cover opened & Paper end", duration: 1.0, position: .center)
        case 0x1A:
            self.view.makeToast("Feeding", duration: 1.0, position: .center)
        case 0x00:
            self.view.makeToast("Cash box open", duration: 1.0, position: .center)
        case 0x01:
            self.view.makeToast("Cash box closed", duration: 1.0, position: .center)
        default:
            self.view.makeToast("Other error", duration: 1.0, position: .center)
        }
    }

    
    @IBAction func openCashBoxAction(_ sender: Any) {
        let command = XPOSCommand()
            .initializePrinter()
            .openCashBox(withPinNumber: CashDrawerPin.pin2)
        printWithData(command.getCommand())
    }
    
    @IBAction func checkCashBoxStatusAction(_ sender: Any) {
        switch ConnectType(rawValue: connectType) {
        case .bluetooth:
            bleManager.cashBoxCheck { status in
                self.cashBoxStatus(status)
            }
        case .wifi:
            wifiManager.cashBoxCheck { status in
                self.cashBoxStatus(status)
            }
        case .mfi:
            let queryData = Data([0x1D, 0x72, 0x02])
            XAccessory.sharedInstance().write(queryData)
        default:
            self.view.makeToast("printer no connect", duration: 1.0, position: .center)
        }
    }
    
    func cashBoxStatus(_ data: Data!) {
        guard data.count > 0 else { return }
        
        if data.count == 1 {
            let status = data.first ?? 0
            if status == 0x00 {
                self.view.makeToast("Cash box open", duration: 1.0, position: .center)
            } else if status == 0x01 {
                self.view.makeToast("Cash box closed", duration: 1.0, position: .center)
            }
        }
    }
    
    @IBAction func printSampleAction(_ sender: Any) {
        let command = XPOSCommand()
            .initializePrinter()
            .addText("              Las vegas,NV5208")
            .printAndFeedLines(2)
            .select(.left)
            .addText("Ticket #30-57320                User:HAPPY")
            .lineFeed()
            .addText("Station:52-102             Sales Rep HAPPY")
            .lineFeed()
            .addText("10/10/2019 3:55:01PM")
            .lineFeed()
            .addText("------------------------------------------")
            .lineFeed()
            .addText("Item             QTY     Price       Total")
            .lineFeed()
            .addText("Description")
            .lineFeed()
            .addText("------------------------------------------")
            .lineFeed()
            .addText("100328            1       7.99        7.99")
            .lineFeed()
            .addText("MAGARITA MIX")
            .lineFeed()
            .addText("680015            4       0.99        3.96")
            .lineFeed()
            .addText("LIME")
            .lineFeed()
            .addText("102501            1      43.99       43.99")
            .lineFeed()
            .addText("VODKA")
            .lineFeed()
            .addText("021048            1       4.99        4.99")
            .lineFeed()
            .addText("ORANGE 320Z")
            .lineFeed()
            .addText("------------------------------------------")
            .lineFeed()
            .addText("Subtotal                             60.93")
            .lineFeed()
            .addText("8.1% Sales Tax                        4.21")
            .lineFeed()
            .addText("2% Concession Recov                   1.04")
            .lineFeed()
            .addText("------------------------------------------")
            .lineFeed()
            .addText("Total                                66.18")
            .printAndFeedLines(2)
            .select(.center)
            .printQRCode(withContent: "www.google.com", moduleSize: 6, ecLevel: QRErrorCorrectionLevel.L)
            .printAndFeedLines(5)
            .cutPaper()
        printWithData(command.getCommand())
    }
    
    // Method to print data
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
}

// MARK: - XBLEManagerDelegate delegate

extension POSPrinterVC: XBLEManagerDelegate {
    
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

extension POSPrinterVC: XWIFIManagerDelegate {
    
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

