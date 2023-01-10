//
//  SensorListCell.swift
//  smartHome
//
//  Created by Rene Hörschinger on 20.11.21.
//

import UIKit

class SensorListCell: UITableViewCell {
    
    @IBOutlet var sensorName: UILabel!
    @IBOutlet var sensorValue: UILabel!
    
    override class func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
