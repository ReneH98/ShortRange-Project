//
//  SensorData.swift
//  smartHome
//
//  Created by Rene Hörschinger on 24.11.21.
//

import Foundation
import CoreBluetooth

struct SensorData: CustomStringConvertible {
    var name: String = ""
    var value: [Double] = []
    var uuid: CBUUID
    var timestamp: [Double] = []
    
    var description: String {
        return "{\"name\": \"\(name)\", \"value\": \(value.description)}"
    }
}
