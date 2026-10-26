//
//  ZPLPrinterVC.swift
//  PrinterDemo
//
//  Created by Apple Mac mini intel on 2024/12/23.
//

import UIKit

class ZPLPrinterVC: UIViewController {
    
    @IBOutlet weak var directionSwitch: UISwitch!
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var densitySlider: UISlider!
    @IBOutlet weak var numSegment: UISegmentedControl!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var densityLabel: UILabel!
    
    // Bluetooth and WiFi manager
    var bleManager: XBLEManager!
    var wifiManager: XWIFIManager!
    
    var connectType: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "ZPL PRINT"
        bleManager = XBLEManager.sharedInstance()
        wifiManager = XWIFIManager.sharedInstance()
    }
    
    @IBAction func printTextAction(_ sender: Any) {
        let command = XZPLCommand()
        command.start()
            .setLabelLength(400)
            .addTextAt(x: 10, y: 0, fontName: kFNT_A, rotation: .ZPLRotation0, sizeW: 9, sizeH: 5, content: "fontA")
            .addTextAt(x: 10, y: 20, fontName: kFNT_B, rotation: .ZPLRotation0, sizeW: 11, sizeH: 7, content: "fontB")
            .addTextAt(x: 10, y: 40, fontName: kFNT_C, rotation: .ZPLRotation0, sizeW: 18, sizeH: 10, content: "fontC")
            .addTextAt(x: 10, y: 60, fontName: kFNT_D, rotation: .ZPLRotation0, sizeW: 18, sizeH: 10, content: "fontD")
            .addTextAt(x: 10, y: 90, fontName: kFNT_F, rotation: .ZPLRotation0, sizeW: 26, sizeH: 13, content: "fontF")
            .addTextAt(x: 10, y: 130, fontName: nil, rotation: .ZPLRotation0, sizeW: 0, sizeH: 0, content: "fontE")
            .addTextAt(x: 10, y: 160, fontName: kFNT_G, rotation: .ZPLRotation0, sizeW: 60, sizeH: 40, content: "fontG")
            .addTextAt(x: 10, y: 220, fontName: kFNT_0, rotation: .ZPLRotation0, sizeW: 15, sizeH: 12, content: "font0")
            .addTextAt(x: 350, y: 250, fontName: kFNT_E, rotation: .ZPLRotation0, sizeW: 28, sizeH: 15, content: "E0")
            .addTextAt(x: 250, y: 250, fontName: kFNT_E, rotation: .ZPLRotation90, sizeW: 28, sizeH: 15, content: "E90")
            .addTextAt(x: 250, y: 350, fontName: kFNT_E, rotation: .ZPLRotation180, sizeW: 28, sizeH: 15, content: "E180")
            .addTextAt(x: 350, y: 350, fontName: kFNT_E, rotation: .ZPLRotation270, sizeW: 28, sizeH: 15, content: "E270")
            .end()
        printWithData(command.getCommand())
    }
    
    @IBAction func printBarcode1Action(_ sender: Any) {
        let command = XZPLCommand()
            .start()
            .setPrinterWidth(560)
        
            .addTextAt(x: 50, y: 100, content: "Code 11")
            .addBarcodeAt(x: 50, y: 150, codeType: ZPLBarCodeType.code11, content: "123456")
        
            .addTextAt(x: 360, y: 100, content: "Code 25")
            .addBarcodeAt(x: 360, y: 150, codeType: ZPLBarCodeType.code25, content: "123456")

            .addTextAt(x: 50, y: 300, content: "Code 39")
            .addBarcodeAt(x: 50, y: 350, codeType: ZPLBarCodeType.code39, content: "CODE39")
        
            .addTextAt(x: 360, y: 300, content: "EAN 8")
            .addBarcodeAt(x: 360, y: 350, codeType: ZPLBarCodeType.codeEAN8, content: "1234567")

            .addTextAt(x: 50, y: 500, content: "UPC E")
            .addBarcodeAt(x: 50, y: 550, codeType: ZPLBarCodeType.codeUPCE, content: "0123456")
            .addTextAt(x: 360, y: 500, content: "Code 93")
            .addBarcodeAt(x: 360, y: 550, codeType: ZPLBarCodeType.code93, content: "CODE93")
        
            .end()

        printWithData(command!.getCommand())
    }

    @IBAction func printBarcode2Action(_ sender: Any) {
        let command = XZPLCommand()
            .start()
            .setPrinterWidth(560)
        
            .addTextAt(x: 20, y: 100, content: "Code 128")
            .addBarcodeAt(x: 20, y: 150, codeType: ZPLBarCodeType.code128, content: "CODE128", height: 90)
        
            .addTextAt(x: 20, y: 100, content: "Code 128")
            .addBarcodeAt(x: 20, y: 150, codeType: ZPLBarCodeType.code128, content: "CODE128", height: 90)
        
            .addTextAt(x: 300, y: 100, content: "EAN 13")
            .addBarcodeAt(x: 300, y: 150, codeType: ZPLBarCodeType.codeEAN13, content: "123456789012", height: 90)

            .addTextAt(x: 20, y: 300, content: "CODA")
            .addBarcodeAt(x: 20, y: 350, codeType: ZPLBarCodeType.codeCODA, content: "123456", height: 90)
        
            .addTextAt(x: 300, y: 300, content: "MSI")
            .addBarcodeAt(x: 300, y: 350, codeType: ZPLBarCodeType.codeMSI, content: "123456", height: 90)

            .addTextAt(x: 20, y: 500, content: "PLESSEY")
            .addBarcodeAt(x: 20, y: 550, codeType: ZPLBarCodeType.codePLESSEY, content: "123456", height: 90)

            .addTextAt(x: 20, y: 700, content: "UPC A")
            .addBarcodeAt(x: 20, y: 750, codeType: ZPLBarCodeType.codeUPCA, content: "123456789012", height: 90)

            .addTextAt(x: 300, y: 700, content: "UPC EAN")
            .addBarcodeAt(x: 300, y: 750, codeType: ZPLBarCodeType.codeUPCEAN, content: "12345", height: 90)
        
            .end()
        
        printWithData(command!.getCommand())
    }

    @IBAction func printQrcodeAction(_ sender: Any) {
        let command = XZPLCommand()
            .start()
            .setPrinterWidth(560)
            .addQRCodeAt(x: 0, y: 100, factor: 6, text: "0123456789ABCD 2D code")
            .end()
        printWithData(command!.getCommand())
    }

    @IBAction func printGeometryAction(_ sender: Any) {
        let command = XZPLCommand()
            .start()
        // Add a rectangle
            .addBoxAt(x: 100, y: 100, width: 200, height: 150, thickness: 10)
        // Add a right diagonal line
            .addGraphicDiagonalLineAt(x: 50, y: 50, orientation: DiagonalDirection.right, width: 400, height: 200, thickness: 5)
        // Add a left diagonal line
            .addGraphicDiagonalLineAt(x: 50, y: 50, orientation: DiagonalDirection.left, width: 400, height: 200, thickness: 5)
        // Add an ellipse
            .addGraphicEllipseAt(x: 150, y: 150, width: 200, height: 100, thickness: 2)
        // Add a circle
            .addGraphicCircleAt(x: 200, y: 200, diameter: 100, thickness: 1)
        
            .end()
        printWithData(command!.getCommand())
        
    }

    @IBAction func printImageAction(_ sender: Any) {
        if let image = UIImage(named: "image") {
            let command = XZPLCommand()
                .start()
                .printImageAt(x: 0, y: 50, image: image)
                .end()
            printWithData(command!.getCommand())
        }
    }
    
    @IBAction func downloadGraphicAction(_ sender: Any) {
        if let image = UIImage(named: "image") {
            let command = XZPLCommand()
                .start()
                .downloadGraphic(ZPLDeviceType.DeviceTypeR, name: "SAMPLE1", image: image)
                .end()
            printWithData(command!.getCommand())
        }
    }
    
    
    @IBAction func printGraphicAction(_ sender: Any) {
        let command = XZPLCommand()
            .start()
            .printGraphicAt(x: 0, y: 0, source: ZPLDeviceType.DeviceTypeR, name: "SAMPLE1", mx: 1, my: 1)
            .end()
        printWithData(command!.getCommand())
    }
    
    @IBAction func deleteGraphicAction(_ sender: Any) {
        let command = XZPLCommand()
            .start()
            .deleteDownloadGraphic(ZPLDeviceType.DeviceTypeR, name: "SAMPLE1")
            .end()
        printWithData(command!.getCommand())
    }
    
    
    @IBAction func setSpeedAction(_ sender: Any) {
        let command = XZPLCommand()
            .start()
            .setPrintSpeed(Int32(speedSlider.value))
            .end()
        printWithData(command!.getCommand())
    }
    
    
    @IBAction func setDensityAction(_ sender: Any) {
        let command = XZPLCommand()
            .start()
            .setPrintDensity(Int32(densitySlider.value))
            .end()
        printWithData(command!.getCommand())
    }
    
    @IBAction func testDirectionAction(_ sender: Any) {
        if let image = UIImage(named: "image") {
            let command = XZPLCommand()
                .start()
                .addTextAt(x: 200, y: 0, content: "image")
                .printImageAt(x: 0, y: 0, image: image)
                .direction(directionSwitch.isOn)
                .end()
            printWithData(command!.getCommand())
        }
    }
    
    @IBAction func printNumAction(_ sender: Any) {
        if let image = UIImage(named: "image") {
            let command = XZPLCommand()
                .start()
                .addTextAt(x: 200, y: 0, content: "image")
                .printImageAt(x: 0, y: 0, image: image)
                .addPrintCount(Int32(numSegment.selectedSegmentIndex + 1))
                .end()
            printWithData(command!.getCommand())
        }
    }
    
    @IBAction func speedValueChanged(_ sender: UISlider) {
        speedLabel.text = "Speed: \(Int(sender.value))"
    }
    
    @IBAction func densityValueChanged(_ sender: UISlider) {
        densityLabel.text = "Density: \(Int(sender.value))"
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
}


