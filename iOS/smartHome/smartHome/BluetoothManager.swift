//
//  BluetoothManager.swift
//  smartHome
//
//  Created by Rene Hörschinger on 18.11.21.
//

import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject {

    private var bluetoothManager: CBCentralManager!
    var peripheralList: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral? = nil
    var sensorData: [SensorData] = []
    var detailViewDataIndex = 0 // this index is used for the detail view controller
    
    // states
    var blSwitchedOn = false
    
    // delegate
    weak var delegate: BluetoothManagerDelegate?
    
    override init() {
        super.init()
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        bluetoothManager.delegate = self
    }
    
    func prepareDataForExport() -> String {
        // MARK: returns a string in json format for UIActivityViewController which takes a list of strings as input
        var dataString = "["
        for data in sensorData {
            if dataString != "[" {
                dataString.append(",")
            }
            dataString.append("{\"name\": \"\(data.name)\", \"value\": \(data.value.description)}")
        }
        dataString.append("]")
        return dataString
    }
    
    func startScanning() {
        // MARK: start bluetooth scanning
        if !bluetoothManager.isScanning {
            bluetoothManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func stopScanning() {
        // MARK: stop bluetooth scanning
        if bluetoothManager.isScanning {
            bluetoothManager.stopScan()
        }
    }
    
    func refreshPeripheralList() {
        // MARK: refresh peripheral list
        stopScanning()
        peripheralList.removeAll()
        startScanning()
    }
    
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        // MARK: connect to the peripheral
        if connectedPeripheral == nil {
            bluetoothManager.connect(peripheral)
        }
    }
    
    func disconnectFromPeripheral() {
        // MARK: disconnect the peripheral
        if let connectedPeripheral = connectedPeripheral {
            bluetoothManager.cancelPeripheralConnection(connectedPeripheral)
        }
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let peripheralName = peripheral.name,
        peripheralName.starts(with: "SmartHome"),
           !peripheralList.contains(where: { $0.identifier == peripheral.identifier }){
            // only add peripheral to the list if it is a new one, and starts with a specific string, probably "SmartHome", all BLE devices (ESP32) must of course be named SmartHome_someID/Name then
            peripheralList.append(peripheral)
            print("New ble device: \(peripheralName)")
            
            // also let the delegate know there is a new device
            delegate?.newPeripheralFound()
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            blSwitchedOn = true
        } else {
            blSwitchedOn = false
            peripheralList.removeAll()
            
            if connectedPeripheral != nil {
                // MARK: bluetooth status has changed to off even though a peripheral is connected, now lets handle this
                connectedPeripheral = nil
                delegate?.updatedConnection(false)
            }
            
        }
        delegate?.updatedSwitchedOn(blSwitchedOn)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to: \(peripheral.name ?? "")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        stopScanning()
        delegate?.updatedConnection(true)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        /*
         MARK: The problem with this: it only works if none of the following happens:
         - device reboot
         - bluetooth radio being turned off and back on
         - Airplane mode turned on then off
         - If, for some reason, the BLE stack crashes
         - And, most importantly, user force quits your app
         */
        if let error = error {
            print(error)
            delegate?.newErrorMessage("Error: didDisconnectPeripheral")
            // if this function is called with an error -> it is not a willing disconnect, so lets try to reconnect
            connectedPeripheral = nil
            connectToPeripheral(peripheral)
            return
        }
        print("disconnect from: \(peripheral.name ?? "")")
        connectedPeripheral = nil
        peripheralList.removeAll()
        delegate?.updatedConnection(false)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(error)
            delegate?.newErrorMessage("Error: didFailToConnect")
            return
        }
        print("did fail to connect")
    }
    
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print(error)
            delegate?.newErrorMessage("Error: didDiscoverServices")
            return
        }
        
        if let services = peripheral.services as [CBService]? {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print(error)
            delegate?.newErrorMessage("Error: didDiscoverCharacteristicsFor")
            return
        }
        guard let characteristics = service.characteristics as [CBCharacteristic]? else { return }
        for newChar in characteristics {
            peripheral.discoverDescriptors(for: newChar)
            peripheral.readValue(for: newChar)
            peripheral.setNotifyValue(true, for: newChar)
            if sensorData.isEmpty ||
                !sensorData.contains(where: { $0.uuid == newChar.uuid }){
                sensorData.append(SensorData(uuid: newChar.uuid))
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error)
            delegate?.newErrorMessage("Error: didDiscoverDescriptorsFor")
            return
        }
        guard let descriptors = characteristic.descriptors else { return }
        for descriptor in descriptors {
            peripheral.readValue(for: descriptor)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if let error = error {
            print(error)
            delegate?.newErrorMessage("Error: didUpdateValueFor")
            return
        }
        switch descriptor.uuid.uuidString {
        case CBUUIDCharacteristicExtendedPropertiesString:
            guard let properties = descriptor.value as? NSNumber else {
                break
            }
            print("Extended properties: \(properties)")
        case CBUUIDCharacteristicUserDescriptionString:
            // get name of description here, which should be the name displayed for each ble characteristic in the list
            guard let description = descriptor.value as? NSString,
                  let uuid = descriptor.characteristic?.uuid else {
                break
            }
            print("User description: \(description)")
            if let row = sensorData.firstIndex(where: { $0.uuid == uuid }) {
                sensorData[row].name = String(description)
                delegate?.newCharacteristicFound()
            }
        case CBUUIDClientCharacteristicConfigurationString:
            guard let clientConfig = descriptor.value as? NSNumber else {
                break
            }
            print("Client configuration: \(clientConfig)")
        case CBUUIDServerCharacteristicConfigurationString:
            guard let serverConfig = descriptor.value as? NSNumber else {
                break
            }
            print("Server configuration: \(serverConfig)")
        case CBUUIDCharacteristicFormatString:
            guard let format = descriptor.value as? NSData else {
                break
            }
            print("Format: \(format)")
        case CBUUIDCharacteristicAggregateFormatString:
            print("Aggregate Format: (is not documented)")
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // MARK: main function to receive ble messages as byte streams, first transform them back to double values, and divide by 100 to get the digits back, then add it to the sensordata array
        if let error = error {
            print(error)
            delegate?.newErrorMessage("Error: didUpdateValueFor")
            return
        }
        guard let value = characteristic.value as Data? else { return }
        if value.count == 0 { return }
        let bytes = NSData.init(data: value).bytes
        let y = bytes.load(as: UInt32.self)
        let doubleValue = Double(y) / 100 // transform data back to float values with 2 digits
        
        if doubleValue < -20 || doubleValue > 5000 {
            // these values are generally not possible, if such a value appears, this must might a transmission error
            return
        }
        
        if let row = sensorData.firstIndex(where: { $0.uuid == characteristic.uuid }) {
            sensorData[row].value.append(doubleValue)
            sensorData[row].timestamp.append(Double(NSDate().timeIntervalSince1970))
            
            if sensorData[row].name != "" {
                // if the name is empty, this means the description has not been discovered yet, so we should not use the data without the domain knowledge of what the data is, and therefor we only notify our delegate if a name is set
                delegate?.newValueReceived(for: characteristic.uuid)
                if characteristic.uuid.uuidString.lowercased() == "d7d2905a-1233-11ec-82a8-0242ac130003" {
                    // this is the uuid from the co2 sensor, this "needs" to be hardcoded in someway
                    if doubleValue > 1400 {
                        delegate?.showCO2Notification()
                    } else {
                        delegate?.removeCO2Notification()
                    }
                }
            }
        }
    }
    
}
