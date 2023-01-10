//
//  WeatherItem.swift
//  smartHome
//
//  Created by Rene Hörschinger on 21.11.21.
//

import Foundation

struct WeatherItem {
    
    enum CodingKeys: String, CodingKey {
        case name
        case main
    }
    
    enum WeatherKeys: String, CodingKey {
        case temperature = "temp"
        case humidity = "humidity"
    }
    
    var name: String
    var temperature: Double
    var humidity: Double
    
    init(name: String, temperature: Double, humidity: Double) {
        self.name = name
        self.temperature = temperature
        self.humidity = humidity
    }
}

extension WeatherItem: Decodable {
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        
        let mainValues = try container.nestedContainer(keyedBy: WeatherKeys.self, forKey: .main)
        let temperature = try mainValues.decode(Double.self, forKey: .temperature)
        let humidity = try mainValues.decode(Double.self, forKey: .humidity)
        
        self.init(name: name, temperature: Double(temperature), humidity: Double(humidity))
    }
    
}
