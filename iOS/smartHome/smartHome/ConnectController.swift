//
//  ConnectController.swift
//  smartHome
//
//  Created by Rene Hörschinger on 18.11.21.
//

import UIKit

class ConnectController: UIViewController {
    
    @IBOutlet var refreshButton: UIButton!
    @IBOutlet var tableView: UITableView!
    var bleManager: BluetoothManager? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        
        // only start scanning if the connect view appears, otherwise it does not make sense to scan for ble devices as this drains battery life
        if let bleManager = bleManager {
            bleManager.delegate = self
            bleManager.startScanning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // MARK: if connect view gets dismissed -> stop scanning in order to safe battery life
        if let bleManager = bleManager {
            bleManager.stopScanning()
        }
    }
    
    @IBAction func refreshButtonPressed(_ sender: Any) {
        // MARK: a refresh button to remove the peripheral list and load it new
        if let bleManager = bleManager {
            bleManager.refreshPeripheralList()
        }
    }
    
}

extension ConnectController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let bleManager = bleManager {
            return bleManager.peripheralList.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "connectCellIdentifier", for: indexPath) as? ConnectTableViewCell else {
            fatalError("Could not create TableViewCell")
        }
        
        if let bleManager = bleManager {
            let peripheral = bleManager.peripheralList[indexPath.row]
            cell.label.text = "\(peripheral.name ?? "NONAME")"
        }
        
        return cell
    }
    
}

extension ConnectController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let bleManager = bleManager else { return }
        let peripheral = bleManager.peripheralList[indexPath.row]
        
        // show alert to ask user if he wants to connect to this device
        let alert = UIAlertController(title: "Do you want to connect?", message: "Device: \(peripheral.name ?? "")", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {_ in
            bleManager.connectToPeripheral(peripheral)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        self.present(alert, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ConnectController: BluetoothManagerDelegate {
    func newPeripheralFound() {
        DispatchQueue.main.async() {
            self.tableView.reloadData()
        }
    }
    
    func updatedConnection(_ status: Bool) {
        // if a connection is established, pop the current view and go back to the homescreen
        if status == true {
            if let navController = self.navigationController {
                navController.popViewController(animated: true)
            }
        }
    }
    
    func updatedSwitchedOn(_ status: Bool) {
        if status == false {
            if let navController = self.navigationController {
                navController.popViewController(animated: true)
            }
        }
    }
}
