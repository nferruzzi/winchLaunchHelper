//
//  AHISApp.swift
//  AHIS
//
//  Created by nferruzzi on 07/01/21.
//

import SwiftUI

final class Services: ObservableObject {
    static var shared: Services = .init()
    
    var ahService: DeviceMotionProtocol
    var msService: MachineStateProtocol
    var replayURL: URL?
    
    @Published var viewModel: AHServiceViewModel
    
    init() {
        let service = DeviceMotionService() // ReplayDeviceMotionService(bundle: "k2_apollonia_strong_wind_1.json")
        self.ahService = service
        self.msService = MachineStateService(ahService: service)
        self.viewModel = AHServiceViewModel(ahService: ahService, machineStateService: msService)
    }
    
    func setup(replay: URL?) {
        guard replay != self.replayURL else { return }
        self.ahService.stop()
        self.viewModel.stop()

        self.replayURL = replay
        if let replay = replay {
            let service = ReplayDeviceMotionService(fileURL: replay)
            self.ahService = service
            self.msService = MachineStateService(ahService: service)
        } else {
            let service = DeviceMotionService()
            self.ahService = service
            self.msService = MachineStateService(ahService: service)
        }
        
        self.viewModel = AHServiceViewModel(ahService: ahService, machineStateService: msService)
    }
}

@main
struct AHISApp: App {
    @ObservedObject var services = Services.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: services.viewModel)
            .preferredColorScheme(.dark)
        }
    }
}
