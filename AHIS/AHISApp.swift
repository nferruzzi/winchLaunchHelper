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
//        static let ahService: DeviceMotionProtocol = ReplayDeviceMotionService(bundle: "k2_apollonia_strong_wind_1.json")
        static let msService: MachineStateProtocol = MachineStateService(ahService: Self.ahService)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: AHServiceViewModel(ahService: Constants.ahService,
                                                  machineStateService: Constants.msService))
            .preferredColorScheme(.dark)
        }
    }
}
