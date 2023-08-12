//
//  CMLogItem+date.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import Foundation
import CoreMotion


extension CMLogItem {
    static var bootTime = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)

    var date: Date {
        CMLogItem.bootTime.addingTimeInterval(timestamp)
    }
}

extension Date {
    var timeIntervalSinceBootTime: TimeInterval {
        timeIntervalSince(CMLogItem.bootTime)
    }
}
