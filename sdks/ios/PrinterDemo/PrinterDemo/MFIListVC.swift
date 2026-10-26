//
//  MFIListVC.swift
//  PrinterDemo
//
//  Created by Apple Mac mini intel on 3/21/25.
//

import UIKit
import ExternalAccessory
import CoreBluetooth
class MFIListVC: UIViewController,UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var mfiTableView: UITableView!
    private var accessoryList: [EAAccessory] = []
    private var supportedProtocolsStrings: [String] = []
    var selectedAccessory: EAAccessory?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Listen for peripheral connection notifications
        NotificationCenter.default.addObserver(self, selector: #selector(accessoryDidConnect(_:)), name: .EAAccessoryDidConnect, object: nil)
        
        // Listen for peripheral disconnection notifications
        NotificationCenter.default.addObserver(self, selector: #selector(accessoryDidDisconnect(_:)), name: .EAAccessoryDidDisconnect, object: nil)
        
        // Register for local notifications
        EAAccessoryManager.shared().registerForLocalNotifications()
        
        // Get the list of connected peripherals
        accessoryList = EAAccessoryManager.shared().connectedAccessories
        
        // Read `UISupportedExternalAccessoryProtocols` from Info.plist
        if let protocols = Bundle.main.object(forInfoDictionaryKey: "UISupportedExternalAccessoryProtocols") as? [String] {
            supportedProtocolsStrings = protocols
        }
        
    }
    
    
    @objc func accessoryDidConnect(_ notification: Notification) {
        if let connectedAccessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            accessoryList.append(connectedAccessory)
            let indexPath = IndexPath(row: accessoryList.count - 1, section: 0)
            mfiTableView.insertRows(at: [indexPath], with: .left)
        }
    }

    @objc func accessoryDidDisconnect(_ notification: Notification) {
        guard let disconnectedAccessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
        
        // Clear the selected accessory (if the disconnected one is currently selected)
        if let selected = selectedAccessory, disconnectedAccessory.connectionID == selected.connectionID {
            selectedAccessory = nil
        }
        
        // Find the index of the disconnected device
        if let index = accessoryList.firstIndex(where: { $0.connectionID == disconnectedAccessory.connectionID }) {
            accessoryList.remove(at: index)
            
            let indexPath = IndexPath(row: index, section: 0)
            mfiTableView.deleteRows(at: [indexPath], with: .right)
        } else {
            print("Unable to find the disconnected device")
        }
    }
    
    // MARK: - UITableViewDelegate and UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accessoryList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let eaAccessoryCellIdentifier = "eaAccessoryCellIdentifier"
        let row = indexPath.row
        
        var cell = tableView.dequeueReusableCell(withIdentifier: eaAccessoryCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: eaAccessoryCellIdentifier)
        }
        
        let eaAccessoryName = accessoryList[row].name.isEmpty ? "unknown" : accessoryList[row].name
        cell?.textLabel?.text = eaAccessoryName
        
        return cell!
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        selectedAccessory = accessoryList[row]
        
        let protocolStrings = selectedAccessory?.protocolStrings ?? []
        var selectedProtocol: String?
        
        var matchFound = false
        for protocolString in protocolStrings {
            if supportedProtocolsStrings.contains(protocolString) {
                matchFound = true
                selectedProtocol = protocolString
                break
            }
        }
        
        if matchFound, let protocolString = selectedProtocol {
            XAccessory.sharedInstance().setupController(for: selectedAccessory!, withProtocolString: protocolString)
            if (XAccessory.sharedInstance().openSession()) {
                NotificationCenter.default.post(name: Notification.Name("openSession"), object: nil)
                navigationController?.popViewController(animated: true)
            }
        } else {
            print("protocolString unregistered")
        }
    }


}
