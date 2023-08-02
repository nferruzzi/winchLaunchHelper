//
//  AHISApp.swift
//  AHIS
//
//  Created by nferruzzi on 07/01/21.
//

import SwiftUI

@main
struct AHISApp: App {
    enum Constants {
        static let ahService: DeviceMotionProtocol = DeviceMotionService()
        static let msService: MachineStateProtocol = SpeedProcessor(speedPublisher: ahService.speed)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: AHServiceViewModel(ahService: Constants.ahService,
                                                  machineStateService: Constants.msService))
        }
    }
}
