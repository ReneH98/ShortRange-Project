//
//  DetailViewController.swift
//  smartHome
//
//  Created by Rene Hörschinger on 21.11.21.
//

import Foundation
import UIKit
import Charts
import CoreBluetooth

class DetailViewController: UIViewController, ChartViewDelegate {
    
    @IBOutlet var clearDataButton: UIBarButtonItem!
    var bleManager: BluetoothManager? = nil
    private var lineChart = LineChartView()
    @IBOutlet var firstDataDate: UILabel!
    @IBOutlet var lastDataDate: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        lineChart.delegate = self
        if let bleManager = bleManager {
            bleManager.delegate = self
            let data = bleManager.sensorData[bleManager.detailViewDataIndex]
            updateLabels(data)
        }
    }
    
    private func updateLabels(_ data: SensorData) {
        if data.timestamp.count != 0 {
            let format = DateFormatter()
            format.timeZone = .current
            format.dateFormat = "dd.MM.yyyy HH:mm:ss"
            var dateString = format.string(from: Date(timeIntervalSince1970: data.timestamp[0]))
            firstDataDate.text = "First data received: \(dateString)"
            if let last = data.timestamp.last {
                dateString = format.string(from: Date(timeIntervalSince1970: last))
                lastDataDate.text = "Last data received: \(dateString)"
            }
        }
    }
    
    @IBAction func clearDataButtonPressed(_ sender: Any) {
        // MARK: user can remove the current data
        let alert = UIAlertController(title: "Do you want to clear the data?", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {_ in
            if let bleManager = self.bleManager {
                let index = bleManager.detailViewDataIndex
                bleManager.sensorData[index].timestamp.removeAll()
                bleManager.sensorData[index].value.removeAll()
                self.firstDataDate.text = ""
                self.lastDataDate.text = ""
                self.lineChart.data = nil
                if let navController = self.navigationController {
                    navController.popViewController(animated: true)
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        lineChart.frame = CGRect(x: 0, y: self.view.frame.height * 1/3 - 50,
                                 width: self.view.frame.size.width,
                                 height: self.view.frame.size.height * 2/3 - 50)
        view.addSubview(lineChart)
        
        if let bleManager = bleManager {
            let index = bleManager.detailViewDataIndex
            let data = bleManager.sensorData[index]
            if !data.value.isEmpty {
                var entries = [ChartDataEntry]()
                for (i, y) in data.value.enumerated() {
                    let x = (data.timestamp[i] - data.timestamp[0]) / 60 // normalize x axis (timestamps) to 0 for the start and unit in minutes
                    entries.append(ChartDataEntry(x: x, y: y))
                }
                let set = LineChartDataSet(entries: entries, label: data.name)
                set.drawCirclesEnabled = false
                set.drawValuesEnabled = false                
                let lineChartData = LineChartData(dataSet: set)
                lineChart.data = lineChartData
            }
        }
    }
    
}

extension DetailViewController: BluetoothManagerDelegate {
    func newValueReceived(for uuid: CBUUID) {
        if let bleManager = bleManager{
            let data = bleManager.sensorData[bleManager.detailViewDataIndex]
            if data.uuid == uuid,
               let lastValue = data.value.last,
               let lastTimeStamp = data.timestamp.last {
                let x = (lastTimeStamp - data.timestamp[0]) / 60
                // lineChart.data?.addEntry(ChartDataEntry(x: x, y: lastValue))
                lineChart.data?.appendEntry(ChartDataEntry(x: x, y: lastValue), toDataSet: 0)
                updateLabels(data)
            }
        }
    }
}
