//
//  ViewController.swift
//  PrinterDemo
//
//  Created by Apple Mac mini intel on 2024/12/23.
//
import UIKit

enum ConnectType: Int {
    case none = 0   // No connection
    case bluetooth  // Bluetooth
    case wifi       // WiFi
    case mfi        // SPP or USB, requires MFI certification
}

class ViewController: UIViewController {
    
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var netLabel: UILabel!
    @IBOutlet weak var netTextField: UITextField!
    @IBOutlet weak var bleSelectButton: UIButton!
    @IBOutlet weak var connectNetButton: UIButton!
    @IBOutlet weak var tsplButton: UIButton!
    @IBOutlet weak var posButton: UIButton!
    @IBOutlet weak var zplButton: UIButton!
    @IBOutlet weak var cpclButton: UIButton!
    @IBOutlet weak var connecySeg: UISegmentedControl!
    
    var connectType: ConnectType = .none
    var bleManager: XBLEManager!
    var wifiManager: XWIFIManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Home"
        
        bleManager = XBLEManager.sharedInstance()
        bleManager.delegate = self
        
        wifiManager = XWIFIManager.sharedInstance()
        wifiManager.delegate = self
        
        buttonStateOff()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(keyboardDismiss))
        self.view.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(tapGesture)

        // Listen for openSession notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(openSession),
                                               name: Notification.Name("openSession"),
                                               object: nil)

        // Listen for EAAccessoryDidDisconnectNotification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(accessoryDidDisconnect(_:)),
                                               name: .EAAccessoryDidDisconnect,
                                               object: nil)

    }
    
    @objc func openSession() {
        print("Session opened")
        buttonStateOn()
        self.view.makeToast("Connect success.", duration: 1.0, position: .center)
        connectType = .mfi
    }
    
    @objc func accessoryDidDisconnect(_ notification: Notification) {
        if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            print("Accessory disconnected: \(accessory.name)")
            if (connecySeg.selectedSegmentIndex == 2) {
                buttonStateOff()
                self.view.makeToast("Disconnect.", duration: 1.0, position: .center)
            }
        }
    }
    
    deinit {
        bleManager.removeDelegate(self)
        wifiManager.removeDelegate(self)
    }
    
    func buttonStateOn() {
        disconnectButton.isEnabled = true
        tsplButton.isEnabled = true
        posButton.isEnabled = true
        zplButton.isEnabled = true
        cpclButton.isEnabled = true
        connecySeg.isEnabled = false
    }
    
    func buttonStateOff() {
        disconnectButton.isEnabled = false
        tsplButton.isEnabled = false
        posButton.isEnabled = false
        zplButton.isEnabled = false
        cpclButton.isEnabled = false
        connecySeg.isEnabled = true
    }
    
    @IBAction func switchConnectMethodAction(_ sender: UISegmentedControl) {
        netLabel.isHidden = sender.selectedSegmentIndex == 0
        connectNetButton.isHidden = sender.selectedSegmentIndex == 0
        netTextField.isHidden = sender.selectedSegmentIndex == 0
        bleSelectButton.isHidden = sender.selectedSegmentIndex == 1
        
        switch sender.selectedSegmentIndex {
        case 0:
            connectType = .bluetooth
            bleSelectButton.setTitle("Scan Bluetooth", for: UIControl.State.normal)
        case 1:
            connectType = .wifi
        case 2:
            connectType = .mfi
            bleSelectButton.setTitle("Scan MFI", for: UIControl.State.normal)
        default: break
        }
    }
    
    @IBAction func connectAction(_ sender: UIButton) {
        guard netTextField.text?.isEmpty == false else {
            self.view.makeToast("Please input net address", duration: 1.0, position: .center)
            return
        }
        
        if wifiManager.isConnected {
            wifiManager.disconnect()
        }
        
        keyboardDismiss()
        wifiManager.connect(withHost: netTextField.text!, port: 9100)
    }
    
    @IBAction func disconnectAction(_ sender: UIButton) {
        if connectType == .bluetooth {
            bleManager.disconnectRootPeripheral()
        } else if connectType == .wifi {
            wifiManager.disconnect()
        } else if connectType == .mfi {
            XAccessory.sharedInstance().closeSession()
            buttonStateOff()
            self.view.makeToast("Disconnect.", duration: 1.0, position: .center)
        }
    }
    
    @objc func keyboardDismiss() {
        netTextField.resignFirstResponder()
    }
    
    func toast(with data: Data) {
        var status: UInt8 = 0
        if data.count == 1 {
            status = data.withUnsafeBytes { $0.load(as: UInt8.self) }
        } else if data.count == 2 {
            status = data.withUnsafeBytes { $0.load(fromByteOffset: 1, as: UInt8.self) }
        }
        
        switch status {
        case 0x00:
            self.view.makeToast("Ready", duration: 1.0, position: .center)
        case 0x01:
            self.view.makeToast("Cover opened", duration: 1.0, position: .center)
        case 0x02:
            self.view.makeToast("Paper jam", duration: 1.0, position: .center)
        case 0x03:
            self.view.makeToast("Cover opened and paper jam", duration: 1.0, position: .center)
        case 0x04:
            self.view.makeToast("Paper end", duration: 1.0, position: .center)
        case 0x05:
            self.view.makeToast("Cover opened and Paper end", duration: 1.0, position: .center)
        case 0x08:
            self.view.makeToast("No Ribbon", duration: 1.0, position: .center)
        case 0x09:
            self.view.makeToast("Cover opened and no Ribbon", duration: 1.0, position: .center)
        case 0x10:
            self.view.makeToast("Pause", duration: 1.0, position: .center)
        case 0x20:
            self.view.makeToast("Printing..", duration: 1.0, position: .center)
        default:
            break
        }
    }
    
    // MARK: - Segue Actions
    
    
    @IBAction func scanDeviceVC(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if (connecySeg.selectedSegmentIndex == 0) {
            if let targetVC = storyboard.instantiateViewController(withIdentifier: "BleListVCID") as? BleListVC {
                self.navigationController?.pushViewController(targetVC, animated: true)
            }
        } else if (connecySeg.selectedSegmentIndex == 2) {
            if let targetVC = storyboard.instantiateViewController(withIdentifier: "MFIListVCID") as? MFIListVC {
                self.navigationController?.pushViewController(targetVC, animated: true)
            }
        }
    }
    
    @IBSegueAction func tsplPrinterVC(_ coder: NSCoder, sender: Any?, segueIdentifier: String?) -> TSPLPrinterVC? {
        let tsplVc = TSPLPrinterVC(coder: coder)
        tsplVc?.connectType = Int(connectType.rawValue)
        return tsplVc
    }
    
    @IBSegueAction func posPrinterVC(_ coder: NSCoder, sender: Any?, segueIdentifier: String?) -> POSPrinterVC? {
        let posVc = POSPrinterVC(coder: coder)
        posVc?.connectType = Int(connectType.rawValue)
        return posVc
    }
    
    @IBSegueAction func zplPrinterVC(_ coder: NSCoder, sender: Any?, segueIdentifier: String?) -> ZPLPrinterVC? {
        let zplVc = ZPLPrinterVC(coder: coder)
        zplVc?.connectType = Int(connectType.rawValue)
        return zplVc
    }
    
    @IBSegueAction func cpclPrinterVC(_ coder: NSCoder, sender: Any?, segueIdentifier: String?) -> CPCLPrinterVC? {
        let cpclVc = CPCLPrinterVC(coder: coder)
        cpclVc?.connectType = Int(connectType.rawValue)
        return cpclVc
    }
    
}


// MARK: - XBLEManagerDelegate delegate

extension ViewController: XBLEManagerDelegate {
    
    func xbleCentralManagerDidUpdateState(_ state: Int) {
        print("Central Manager State Updated: \(state)")
        switch state {
        case 0:
            print("State: Unknown")
        case 1:
            print("State: Resetting")
        case 2:
            print("State: Unsupported")
        case 3:
            print("State: Unauthorized")
        case 4:
            print("State: Powered Off")
        case 5:
            print("State: Powered On")
        default:
            print("State: Undefined")
        }
    }
    
    func xbleConnect(_ peripheral: CBPeripheral!) {
        connectType = .bluetooth
        bleSelectButton.setTitle(peripheral.name, for: .normal)
        self.view.makeToast("Connect success.", duration: 1.0, position: .center)
        buttonStateOn()
    }
    
    func xbleDisconnectPeripheral(_ peripheral: CBPeripheral!, error: Error!) {
        if wifiManager.isConnected {
            connectType = .wifi
        } else {
            self.view.makeToast("Disconnect.", duration: 1.0, position: .center)
            connectType = .none
            bleSelectButton.setTitle("Scan Bluetooth", for: .normal)
            buttonStateOff()
        }
    }
    
}


// MARK: - XBLEManagerDelegate delegate

extension ViewController: XWIFIManagerDelegate {
    
    func xWifiConnected(toHost host: String!, port: UInt16) {
        connectType = .wifi
        self.view.makeToast("Connect success.", duration: 1.0, position: .center)
        buttonStateOn()
        
        wifiManager.printerPOSStatus { status in
        }
    }
    
    func xWifiDisconnectWithError(_ error: Error!) {
        if bleManager.isConnected {
            connectType = .bluetooth
        } else {
            self.view.makeToast("Disconnect.", duration: 1.0, position: .center)
            connectType = .none
            buttonStateOff()
        }
        
        if let error = error {
            self.view.makeToast("\(error)", duration: 2.0, position: .center)
        }
    }
    
}



