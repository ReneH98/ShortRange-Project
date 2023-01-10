//
//  LocationManager.swift
//  smartHome
//
//  Created by Rene Hörschinger on 21.11.21.
//

import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject{
    
    enum NetworkError: Error {
        case couldNotParseUrl
        case noResponseData
    }
    
    private var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.distanceFilter = 100
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return manager
    }()
    private var authorizationStatus: CLAuthorizationStatus
    var locationPermission = false
    var isUpdatingLocation = false
    private var location: CLLocation? = nil
    private let urlSession = URLSession.shared
    var listItems: [[String]] = []
    var cityName: String? = nil
    private let APIkey = "f3a38d1ee95c8a916a69155add8a9719"
    
    weak var delegate: LocationManagerDelegate?
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationData() {
        if !locationPermission {
            requestLocationPermission()
        } else {
            locationManager.startUpdatingLocation()
            isUpdatingLocation = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.isUpdatingLocation {
                    self.locationManager.stopUpdatingLocation()
                }
            }
            
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestWeatherFromAPI(locationName: String, completion: @escaping (WeatherItem?, Error?) -> Void) {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(locationName)&units=metric&appid=\(APIkey)"
        guard let urlEncodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { completion(nil, NetworkError.couldNotParseUrl)
            return
        }
        guard let url = URL(string: urlEncodedString) else {
            completion(nil, NetworkError.couldNotParseUrl)
            return
        }
        
        print("Send new API request...")
        let task = urlSession.dataTask(with: url) { data, response, error in
            if error != nil {
                completion(nil, error)
            }
            
            guard let responseData = data else {
                completion(nil, NetworkError.noResponseData)
                return
            }
            
            let decoder = JSONDecoder()
            do {
                let weatherItem = try decoder.decode(WeatherItem.self, from: responseData)
                completion(weatherItem, nil)
            } catch {
                completion(nil, error)
            }
        }
        task.resume()
    }
    
    func getCity(for location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print(error)
                completion(nil)
                return
            }
            guard let placemark = placemarks?[0] else {
                completion(nil)
                return
            }
            completion(placemark.locality)
        }
    }
    
    func getNewLocationDataFrom(city: String) {
        self.requestWeatherFromAPI(locationName: city, completion: { weatherItem, error in
            if let error = error {
                print(error)
                return
            }
            guard let item = weatherItem else { return }
            self.listItems = [
                ["Temperature [°C]", String(item.temperature)],
                ["Humidity [%]", String(item.humidity)]
            ]
            self.delegate?.newLocationUpdate()
        })
    }
    
}

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("Authorization status: \(authorizationStatus)")
        switch authorizationStatus {
            case .notDetermined:
                print("not determined")
                locationPermission = false
            case .restricted:
                print("restricted")
                locationPermission = false
            case .denied:
                print("denied")
                locationPermission = false
            case .authorizedAlways:
                print("authorizedAlways")
                locationPermission = true
            case .authorizedWhenInUse:
                print("authorizedWhenInUse")
                locationPermission = true
            default:
                locationPermission = false
        }
        
        if locationPermission {
            locationManager.startUpdatingLocation()
            isUpdatingLocation = true
        } else {
            locationManager.stopUpdatingLocation()
            isUpdatingLocation = false
        }
        
        delegate?.permissionChanged()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
        location = locations[0]
        guard let location = location else { return }
        getCity(for: location, completion: { city in
            guard let city = city else { return }
            self.cityName = city
            print("New GPS Location: \(city)")
            self.getNewLocationDataFrom(city: city)
        })
    }
    
}
