//
//  ViewController.swift
//  smartHome
//
//  Created by Rene Hörschinger on 18.11.21.
//

import UIKit
import CoreBluetooth

class HomescreenController: UIViewController {
    
    @IBOutlet var locationButton: UIBarButtonItem!
    @IBOutlet var clearButton: UIBarButtonItem!
    @IBOutlet var uploadButton: UIBarButtonItem!
    @IBOutlet var connectionStatus: UILabel!
    @IBOutlet var connectionButton: UIButton!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var errorLabel: UILabel!
    
    private var bleManager = BluetoothManager()
    private var locationManager = LocationManager()
    
    // MARK: - View functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        bleManager.delegate = self
        locationManager.delegate = self
        updateLabels()
        
        requestNotificationPermissions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        bleManager.delegate = self
        updateLabels()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.async() {
            self.tableView.reloadSections(IndexSet(integer: 0), with: .fade)
        }
    }
    
    // MARK: - Button functions
    
    @IBAction func locationButtonPressed(_ sender: Any) {
        locationManager.requestLocationData()
    }
    
    @IBAction func clearButtonPressed(_ sender: Any) {
        // MARK: alert for clearing the sensordata
        let alert = UIAlertController(title: "Do you want to clear all data?", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {_ in
            if !self.bleManager.sensorData.isEmpty {
                for i in 0...self.bleManager.sensorData.count - 1 {
                    self.bleManager.sensorData[i].value.removeAll()
                    self.bleManager.sensorData[i].timestamp.removeAll()
                }
                DispatchQueue.main.async() {
                    self.tableView.reloadData()
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Clear Error codes", style: .default, handler: {_ in
            self.errorLabel.text = ""
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    @IBAction func uploadButtonPressed(_ sender: Any) {
        // MARK: show uiactivityviewcontroller for uploading the data in json format
        let items = bleManager.prepareDataForExport()
        let ac = UIActivityViewController(activityItems: [items], applicationActivities: nil)
        present(ac, animated: true)
    }
    
    private func badAirQualityNotification() {
        // MARK: show a notification to the user if the airquality is bad (CO2 ppm over 1400)
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications() { notifications in
            // get all delivered notifications, if there is already one, dont notfiy the user again
            if notifications.count > 0 { return }
            
            print("bad air quality value, now show notification")
            
            let content = UNMutableNotificationContent()
            content.title = "Bad air quality!"
            content.subtitle = "Open the window now!"
            content.categoryIdentifier = "alarm"
            content.sound = UNNotificationSound.default
           
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request)
        }
        
    }
    
    @IBAction func connectionButtonPressed(_ sender: Any) {
        // MARK: either acts as a connect or disconnect button for the ble connection
        let title = connectionButton.titleLabel?.text
        if title == "disconnect" {
            let alert = UIAlertController(title: "Do you want to disconnect?", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {_ in
                self.bleManager.disconnectFromPeripheral()
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            self.present(alert, animated: true)
        } else if title == "connect" && !bleManager.blSwitchedOn {
            // if user presses connect button but bluetooth is not turned on then show an alert to turn on bluetooth
            let alert = UIAlertController(title: "Bluetooth turned off.", message: "Please turn on Bluetooth in order to establish a new connection.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {_ in
                print("hello")
            }))
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - Segue functions
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "connectIdentifier" {
            // MARK: only go to the connected view if there is no connection already established and bluetooth is turned on
            if bleManager.connectedPeripheral != nil || !bleManager.blSwitchedOn {
                return false
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "connectIdentifier" {
            let destination = segue.destination as? ConnectController
            destination?.bleManager = bleManager
        }
        
        if segue.identifier == "detailViewIdentifier" {
            let destination = segue.destination as? DetailViewController
            destination?.bleManager = bleManager
        }
    }
    
    // MARK: - Private functions
    
    private func requestNotificationPermissions() {
        // MARK: requests permission to show notifications to the user
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound,.badge]) { granted, error in
            if let error = error {
                print(error)
                return
            }
            print("access granted for notificiations")
        }
    }
    
    private func updateLabels() {
        // MARK: I chose a function to update the status labels and NOT ONLY updating labels in the delegate functions because the bluetooth delegate could be somewhere else (in the connect controller) while the status changes, so this controller would never know the change, so I'd rather update the labels each time the viewcontroller is about to be shown and of course if I get an update from the delegates
    
        if let connectedPeripheral = bleManager.connectedPeripheral {
            connectionStatus.text = "Connected to: \t\(connectedPeripheral.name ?? "")"
            connectionStatus.textColor = .systemGreen
            connectionButton.setTitle("disconnect", for: .normal)
            connectionButton.tintColor = .systemRed
        } else {
            connectionStatus.text = "No active connection"
            connectionStatus.textColor = .systemRed
            connectionButton.setTitle("connect", for: .normal)
            connectionButton.tintColor = .systemBlue
        }
    }
}

extension HomescreenController: LocationManagerDelegate {
    func permissionChanged() {
        updateLabels()
    }
    
    func newLocationUpdate() {
        DispatchQueue.main.async() {
            self.tableView.reloadSections(IndexSet(integer: 1), with: .fade)
        }
        
    }
}

extension HomescreenController: BluetoothManagerDelegate {
    func newErrorMessage(_ error: String) {
        errorLabel.text = error
        errorLabel.textColor = .systemRed
    }
    
    func updatedSwitchedOn(_ status: Bool) {
        if status == false && bleManager.connectedPeripheral != nil {
            /* MARK: how to treat a bluetooth turn off with an established connection: https://github.com/steamclock/bluejay/issues/211
             "That's because the disconnect callbacks are reserved for actual disconnect events that took place (whether CB call didDisconnect), and when Bluetooth is turned off, I believe CoreBluetooth does not actually call didDisconnect at all. Though this could change in any future iOS update.

             At least for now, and in the future, you might need to handle disconnection and Bluetooth off separately, because that's also how CoreBluetooth deals with these 2 events."
             
             this means I need to make sure I do everything as if "didDisconnectPeripheral" would be called
             */
            bleManager.connectedPeripheral = nil
        }
        updateLabels()
    }
    
    func updatedConnection(_ status: Bool) {
        if !status &&
            !bleManager.sensorData.isEmpty{
            // only triggered if disconnected, view is visible AND there is data
            let alert = UIAlertController(title: "Disconnected from device!", message: "Do you want to remove the data or keep it?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Remove", style: .default, handler: {_ in
                self.bleManager.sensorData.removeAll()
                DispatchQueue.main.async() {
                    self.tableView.reloadData()
                }
            }))
            alert.addAction(UIAlertAction(title: "Keep", style: .cancel, handler: nil))
            self.present(alert, animated: true)
        }
        DispatchQueue.main.async() {
            self.tableView.reloadData()
        }
        updateLabels()
    }
    
    func newCharacteristicFound() {
        // MARK: if a new characterstic is found, update the whole table, because this adds a new row
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func newValueReceived(for uuid: CBUUID) {
        // MARK: if only a value will be updated, its enough to update a single row
        if let row = bleManager.sensorData.firstIndex(where: { $0.uuid == uuid }) {
            DispatchQueue.main.async() {
                let indexPath = IndexPath(item: row, section: 0)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    func showCO2Notification() {
        badAirQualityNotification()
    }
    
    func removeCO2Notification() {
        // MARK: if the CO2 level gets lower, the user shouldnt see the notifation anymore
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
}

extension HomescreenController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return bleManager.sensorData.count
        } else if section == 1 {
            return locationManager.listItems.count
        }
        return 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // one for indoor data, one for outdoor data
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Indoor data"
        } else if section == 1 {
            var header = "Outdoor data - "
            if let city = locationManager.cityName {
                header += city
            }
            return header
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "sensorValueCellIdentifier", for: indexPath) as? SensorListCell else {
            fatalError("Could not create TableView")
        }
        
        if indexPath.section == 0 {
            //MARK: - edit section 0 values (indoor)
            let data = bleManager.sensorData[indexPath.row]
            let sensorNameString = NSMutableAttributedString(string: data.name + " ")
            
            if let val = data.value.last {
                cell.sensorValue.text = String(val)
                
                // MARK: if its a CO2 value, also show a little circle colorcoded depending on the air quality
                if data.name.contains("CO2") {
                    let imageAttachment = NSTextAttachment()
                    var image = UIImage(systemName: "circle.fill")
                    if val < 800 {
                        image = image?.withTintColor(.systemGreen)
                    } else if val < 1000 {
                        image = image?.withTintColor(.systemYellow)
                    } else if val < 1400 {
                        image = image?.withTintColor(.systemOrange)
                    } else {
                        image = image?.withTintColor(.systemRed)
                    }
                    imageAttachment.image = image
                    let imageString = NSAttributedString(attachment: imageAttachment)
                    sensorNameString.append(imageString)
                }
                
            } else {
                cell.sensorValue.text = ""
            }
            cell.sensorName.attributedText = sensorNameString
        } else if indexPath.section == 1 {
            //MARK: - edit section 1 values (outdoor)
            let data = locationManager.listItems[indexPath.row]
            cell.sensorName.text = data[0]
            cell.sensorValue.text = data[1]
        }
        
        return cell
    }
    
}

extension HomescreenController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            bleManager.detailViewDataIndex = indexPath.row
            self.performSegue(withIdentifier: "detailViewIdentifier", sender: self)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
