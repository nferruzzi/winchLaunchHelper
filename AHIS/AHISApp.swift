//
//  AHISApp.swift
//  AHIS
//
//  Created by nferruzzi on 07/01/21.
//

import SwiftUI

final class Services: ObservableObject {
    static var shared: Services = .init()
    @Published var ahService: DeviceMotionProtocol
    @Published var msService: MachineStateProtocol
    var replayURL: URL?
    
    init() {
        let service = DeviceMotionService()
        self.ahService = service
        self.msService = MachineStateService(ahService: service)
    }
    
    func setup(replay: URL?) {
        guard replay != self.replayURL else { return }
        self.ahService.stop()
        
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
    }
}

@main
struct AHISApp: App {
    @ObservedObject var services = Services.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: AHServiceViewModel(ahService: services.ahService,
                                                  machineStateService: services.msService))
            .preferredColorScheme(.dark)
        }
    }
}
