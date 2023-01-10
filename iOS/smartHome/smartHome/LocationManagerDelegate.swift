//
//  LocationManagerDelegate.swift
//  smartHome
//
//  Created by Rene Hörschinger on 21.11.21.
//

import Foundation

protocol LocationManagerDelegate: AnyObject {
    func newLocationUpdate()
    func permissionChanged()
}
