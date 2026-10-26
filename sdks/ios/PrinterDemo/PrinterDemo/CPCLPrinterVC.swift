//
//  CPCLPrinterVC.swift
//  PrinterDemo
//
//  Created by Apple Mac mini intel on 2024/12/23.
//

import UIKit
import CoreBluetooth

class CPCLPrinterVC: UIViewController {
    
    // Properties
    var bleManager: XBLEManager!
    var wifiManager: XWIFIManager!
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var alignSeg: UISegmentedControl!
    @IBOutlet weak var speedLabel: UILabel!
    var connectType: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "CPCL PRINT"
        bleManager = XBLEManager.sharedInstance()
        wifiManager = XWIFIManager.sharedInstance()
    }
    
    // Print text action
    @IBAction func printTextAction(_ sender: Any) {
        let command = XCPCLCommand()
            .initializeLabel(withHeight: 240, count: 1)
            .addTextAt(x: 50, y: 0, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont0, content: "CPCLFont0")
            .addTextAt(x: 200, y: 0, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont1, content: "CPCLFont1")
            .addTextAt(x: 50, y: 40, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont2, content: "CPCLFont2")
            .addTextAt(x: 200, y: 40, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont3, content: "CPCLFont3")
            .addTextAt(x: 50, y: 80, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont4, content: "CPCLFont4")
            .addTextAt(x: 200, y: 80, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont5, content: "CPCLFont5")
            .addTextAt(x: 50, y: 120, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont6, content: "CPCLFont6")
            .addTextAt(x: 200, y: 120, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont7, content: "CPCLFont7")
            .addTextAt(x: 50, y: 160, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont24, content: "CPCLFont24")
            .addTextAt(x: 200, y: 160, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont55, content: "CPCLFont55")
            .addPrint()
        printWithData(command.getCommand())
    }
    
    // Print QR code action
    @IBAction func printQrcodeAction(_ sender: Any) {
        let command = XCPCLCommand()
            .initializeLabel(withHeight: 600, count: 1)
            .addQRCodeAt(x: 60, y: 120, codeModel: QRCodeModesCPCL.CPCLQRCodeModeEnhance, cellWidth: 6, content: "ABC123")
            .addPrint()
        printWithData(command.getCommand())
    }
    
    // Print barcode action
    @IBAction func printBarcodeAction(_ sender: Any) {
        let command = XCPCLCommand()
            .initializeLabel(withHeight: 800, count: 1)
            .barcodeText(5)
        
            .addTextAt(x: 50, y: 0, content: "Code 128")
            .addBarcodeAt(x: 50, y: 30, type: CPCLBarCodeType.code128, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "123456789")

            .addTextAt(x: 50, y: 100, content: "UPC-A")
            .addBarcodeAt(x: 50, y: 130, type: CPCLBarCodeType.codeUPCA, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "423456789012")

            .addTextAt(x: 50, y: 200, content: "UPC-E")
            .addBarcodeAt(x: 50, y: 230, type: CPCLBarCodeType.codeUPCE, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "223456")

            .addTextAt(x: 50, y: 300, content: "EAN-13")
            .addBarcodeAt(x: 50, y: 330, type: CPCLBarCodeType.codeEAN13, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "323456791234")

            .addTextAt(x: 50, y: 400, content: "EAN-8")
            .addBarcodeAt(x: 50, y: 430, type: CPCLBarCodeType.codeEAN8, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "52233445")

            .addTextAt(x: 50, y: 500, content: "Code 39")
            .addBarcodeAt(x: 50, y: 530, type: CPCLBarCodeType.code39, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "Code 39")

            .addTextAt(x: 50, y: 600, content: "Code 93")
            .addBarcodeAt(x: 50, y: 630, type: CPCLBarCodeType.code93, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "72233445")

            .addTextAt(x: 50, y: 700, content: "CODABAR")
            .addBarcodeAt(x: 50, y: 730, type: CPCLBarCodeType.codeCODABAR, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "A67859B")

            .addPrint()
        printWithData(command.getCommand())
    }
    
    // Print vertical barcode action
    @IBAction func printBarcodeVAction(_ sender: Any) {
        let command = XCPCLCommand()
            .initializeLabel(withHeight: 300, count: 1)
            .barcodeText(5)
            .addTextAt(x: 50, y: 50, content: "CODABAR")
            .addBarcodeAt(x: 50, y: 100, type: CPCLBarCodeType.codeCODABAR, width: 1, ratio: BarCodeRatioCPCL.CPCLBarCodeRatio1, height: 50, content: "A67859B")
            .addPrint()
        printWithData(command.getCommand())
    }
    
    // Print geometry action
    @IBAction func printGeometryAction(_ sender: Any) {
        let command = XCPCLCommand()
            .initializeLabel(withHeight: 600, count: 1)
            .addBoxAt(x: 0, y: 100, width: 100, height: 200, thickness: 2)
            .addLineAt(x: 0, y: 150, xend: 100, yend: 150, width: 2)
            .addInverseLineAt(x: 0, y: 200, xend: 100, yend: 200, width: 2)
            .addPrint()
        printWithData(command.getCommand())
    }
    
    // Print image action
    @IBAction func printImageAction(_ sender: Any) {
        if let image = UIImage(named: "image") {
            let command = XCPCLCommand()
                .initializeLabel(withHeight: 400, count: 1)
                .addGraphicsAt(x: 0, y: 100, image: image)
                .addPrint()
            printWithData(command.getCommand())
        }
    }
    
    // Align action
    @IBAction func alignAction(_ sender: UISegmentedControl) {
        let command = XCPCLCommand()
            .initializeLabel(withHeight: 240, count: 1)
            .addAlign(AlignmentsCPCL(rawValue: sender.selectedSegmentIndex) ?? AlignmentsCPCL.CPCLAlignmentLeft, end: 0)
            .addTextAt(x: 0, y: 0, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont2, content: "TEXT1234")
            .addTextAt(x: 0, y: 30, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont2, content: "TEXT1234")
            .addTextAt(x: 0, y: 60, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont2, content: "TEXT1234")
            .addTextAt(x: 0, y: 90, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont2, content: "TEXT1234")
            .addPrint()
        printWithData(command.getCommand())
    }
    
    // Speed slider value changed action
    @IBAction func speedValueChangedAction(_ sender: UISlider) {
        speedLabel.text = "Speed: \(Int(sender.value))"
    }
    
    // send speed test action
    @IBAction func sendSpeedTestAction(_ sender: Any) {
        let command = XCPCLCommand()
            .initializeLabel(withHeight: 240, count: 1)
            .addSpeed(Int32(speedSlider.value))
            .addTextAt(x: 0, y: 0, rotation: RotationCPCL.CPCLRotation0, font: FontCPCL.CPCLFont2, content: "TEXT1234")
            .addPrint()
        printWithData(command.getCommand())
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


