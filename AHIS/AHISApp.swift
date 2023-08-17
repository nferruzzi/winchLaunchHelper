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
        static let msService: MachineStateProtocol = MachineStateService(speedPublisher: ahService.speed.eraseToAnyPublisher(),
                                                                         userAccelerationPublisher: ahService.userAcceleration.eraseToAnyPublisher())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: AHServiceViewModel(ahService: Constants.ahService,
                                                  machineStateService: Constants.msService))
        }
    }
}
