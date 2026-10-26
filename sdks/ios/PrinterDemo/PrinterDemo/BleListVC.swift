//
//  BleListVC.swift
//  PrinterDemo
//
//  Created by Apple Mac mini intel on 2024/12/23.
//

import UIKit

class BleListVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var bleTableView: UITableView!
    private var dataArr: [CBPeripheral] = []
    private var rssiList: [NSNumber] = []
    private var indicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "BLE Search"
        
        XBLEManager.sharedInstance().delegate = self
        XBLEManager.sharedInstance().startScan()
    }
    
    deinit {
        XBLEManager.sharedInstance().removeDelegate(self)
    }
    
    // MARK: - UITableViewDelegate and UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArr.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = "printerCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId)
        
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        }
        
        cell?.accessoryType = .disclosureIndicator
        
        if indexPath.row < dataArr.count {
            let peripheral = dataArr[indexPath.row]
            cell?.textLabel?.text = peripheral.name
        }
        
        if indexPath.row < rssiList.count {
            let rssi = rssiList[indexPath.row]
            cell?.detailTextLabel?.text = "RSSI: \(rssi.intValue)"
        }
        
        return cell!
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = dataArr[indexPath.row]

        if XBLEManager.sharedInstance().isConnected {
            XBLEManager.sharedInstance().disconnectRootPeripheral()
        }

        XBLEManager.sharedInstance().connectDevice(peripheral)
    }
    
}

// MARK: - XBLEManagerDelegate delegate
extension BleListVC: XBLEManagerDelegate {
    
    // Discover Bluetooth Peripheral
    func xbleDiscover(_ peripheral: CBPeripheral!, advertisementData: [AnyHashable : Any]!, rssi RSSI: NSNumber!) {
        if !dataArr.contains(peripheral) {
            dataArr.append(peripheral)
        }

        if !rssiList.contains(RSSI) {
            rssiList.append(RSSI)
        }

        bleTableView.reloadData()
    }
    
    // Connection Successful
    func xbleConnect(_ peripheral: CBPeripheral!) {
        print("Connected to Peripheral: \(peripheral.name ?? "Unknown")")
        navigationController?.popViewController(animated: true)
    }
    
    
    // Connection Failed
    func xbleFail(toConnect peripheral: CBPeripheral!, error: Error!) {
        print("Failed to Connect to Peripheral: \(peripheral.name ?? "Unknown")")
        print("Error: \(error.localizedDescription)")
        indicator.stopAnimating()
        self.view.makeToast("connect fail", duration: 1.0, position: .center)
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

}
