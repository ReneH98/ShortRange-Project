//
//  BluetoothManagerDelegate.swift
//  smartHome
//
//  Created by Rene Hörschinger on 18.11.21.
//

import Foundation
import CoreBluetooth

protocol BluetoothManagerDelegate: AnyObject {
    func updatedSwitchedOn(_ status: Bool)
    func updatedConnection(_ status: Bool)
    func newPeripheralFound()
    func newValueReceived(for uuid: CBUUID)
    func newCharacteristicFound()
    func showCO2Notification()
    func removeCO2Notification()
    func newErrorMessage(_ error: String)
}

// MARK: optional protocol functions so they dont need to be implemented everywhere
extension BluetoothManagerDelegate {
    func updatedSwitchedOn(_ status: Bool) {}
    func updatedConnection(_ status: Bool) {}
    func newPeripheralFound() {}
    func newValueReceived(for uuid: CBUUID) {}
    func newCharacteristicFound() {}
    func showCO2Notification() {}
    func removeCO2Notification() {}
    func newErrorMessage(_ error: String) {}
}
