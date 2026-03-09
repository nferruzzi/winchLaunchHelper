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
        if ProcessInfo.processInfo.arguments.contains("-autoReplay"),
           let url = Bundle.main.url(forResource: "k2_apollonia_strong_wind_1", withExtension: "json") {
            let service = ReplayDeviceMotionService(fileURL: url, timeScale: Services.replayTimeScale)
            self.ahService = service
            self.msService = MachineStateService(ahService: service)
            self.replayURL = url
        } else {
            let service = DeviceMotionService()
            self.ahService = service
            self.msService = MachineStateService(ahService: service)
        }
        self.viewModel = AHServiceViewModel(ahService: ahService, machineStateService: msService, isSimulation: replayURL != nil)
    }
    
    static var replayTimeScale: Double {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-replayTimeScale"),
           idx + 1 < ProcessInfo.processInfo.arguments.count,
           let scale = Double(ProcessInfo.processInfo.arguments[idx + 1]) {
            return scale
        }
        return 1.0
    }

    func setup(replay: URL?) {
        guard replay != self.replayURL else { return }
        stopReplay()

        self.replayURL = replay
        if let replay = replay {
            let service = ReplayDeviceMotionService(fileURL: replay, timeScale: Services.replayTimeScale)
            self.ahService = service
            self.msService = MachineStateService(ahService: service)
        } else {
            let service = DeviceMotionService()
            self.ahService = service
            self.msService = MachineStateService(ahService: service)
        }

        self.viewModel = AHServiceViewModel(ahService: ahService, machineStateService: msService, isSimulation: replay != nil)
    }

    func stopReplay() {
        self.ahService.stop()
        self.viewModel.stop()
        self.replayURL = nil

        let service = DeviceMotionService()
        self.ahService = service
        self.msService = MachineStateService(ahService: service)
        self.viewModel = AHServiceViewModel(ahService: ahService, machineStateService: msService, isSimulation: false)
    }
}

@main
struct AHISApp: App {
    @ObservedObject var services = Services.shared
    @AppStorage("disclaimerAccepted") private var disclaimerAccepted = ProcessInfo.processInfo.arguments.contains("-skipDisclaimer")

    var body: some Scene {
        WindowGroup {
            ContentView(model: services.viewModel)
                .preferredColorScheme(.dark)
                .fullScreenCover(isPresented: .constant(!disclaimerAccepted)) {
                    DisclaimerView(accepted: $disclaimerAccepted)
                }
        }
    }
}
