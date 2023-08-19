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
        static let ahService: DeviceMotionProtocol = DeviceMotionService() // MockedDeviceMotionService
//        static let ahService: DeviceMotionProtocol = MockedDeviceMotionService()
//        static let ahService: DeviceMotionProtocol = ReplayDeviceMotionService(bundle: "drive_flat_to_hill_01.json")
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
