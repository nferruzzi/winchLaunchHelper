//
//  AHServiceViewModel.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import Foundation
import Combine
import CoreLocation
import AVFoundation


final class AHServiceViewModel: ObservableObject {
    enum Constants {
        static let synthesizer = AVSpeechSynthesizer()
        static let importantAltitudes: [DataPointLength.ValueType] = [
            .init(value: 1, unit: .meters),
            .init(value: 20, unit: .meters),
//            .init(value: 25, unit: .meters),
            .init(value: 50, unit: .meters),
//            .init(value: 75, unit: .meters),
            .init(value: 100, unit: .meters),
//            .init(value: 150, unit: .meters),
            .init(value: 200, unit: .meters),
            .init(value: 250, unit: .meters),
        ]
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    private var ahService: DeviceMotionProtocol?
    private let machineStateService: MachineStateProtocol?
    
    @Published private(set) var roll: Int = 0
    @Published private(set) var pitch: Int = 0
    @Published private(set) var heading: Double = 0
    
    @Published private(set) var speed: DataPointSpeed.ValueType = .init(value: 0, unit: .metersPerSecond)
    @Published private(set) var gpsSpeed: DataPointSpeed.ValueType = .init(value: 0, unit: .metersPerSecond)
    @Published private(set) var qfe: DataPointAltitude.ValueType = .init(value: 0, unit: .meters)
    @Published private(set) var distanceFromInitialLocation: DataPointLength.ValueType = .init(value: 0, unit: .meters)
    
    @Published private(set) var acceleration: DataPointAcceleration.ValueType = .init(value: 0, unit: .metersPerSecondSquared)
    @Published private(set) var state: MachineState = .waiting
    @Published private(set) var lasSayString: String = ""
    @Published private(set) var altitudeHistory: [Double] = []
    
    @Published private(set) var takingOffDate: Date?
    
    @Published var minSpeed: DataPointSpeed.ValueType {
        didSet {
            ahService?.minSpeed = minSpeed
        }
    }
    
    @Published var maxSpeed: DataPointSpeed.ValueType {
        didSet {
            ahService?.maxSpeed = maxSpeed
        }
    }
    
    @Published var winchLength: DataPointLength.ValueType {
        didSet {
            ahService?.winchLength = winchLength
        }
    }
    
    @Published var record: Bool {
        didSet {
            ahService?.record = record
        }
    }
    
    @Published var importantAltitudes: [DataPointLength.ValueType] = Constants.importantAltitudes
    

    private var lastSayMin: Date?
    private var lastSayMinSpeed: Date?
    private var lastSayMinSpeedLost: Date?
    private var lastSayMaxSpeedReached: Date?
    private var lastSayQFE: Date?
    
    private var zeroAltitude: Double?
    private var initialLocation: CLLocation?
    
    init(ahService: DeviceMotionProtocol? = nil,
         machineStateService: MachineStateProtocol? = nil) {
        
        self.ahService = ahService
        self.machineStateService = machineStateService
        self.minSpeed = ahService?.minSpeed ?? .init(value: 0, unit: .kilometersPerHour)
        self.maxSpeed = ahService?.maxSpeed ?? .init(value: 0, unit: .kilometersPerHour)
        self.winchLength = ahService?.winchLength ?? .init(value: 0, unit: .meters)
        self.record = ahService?.record ?? false
        
        guard let machineStateService = machineStateService,
              let ahService = ahService else { return }
        
        ahService
            .speed
            .map { $0.value.converted(to: .metersPerSecond) }
            .receive(on: DispatchQueue.main)
//            .print("GPS SPEED")
            .assign(to: \.gpsSpeed, on: self)
            .store(in: &subscriptions)

        ahService
            .roll
            .map { Int($0.value.converted(to: .degrees).value) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.roll, on: self)
            .store(in: &subscriptions)
        
        ahService
            .pitch
            .map { Int($0.value.converted(to: .degrees).value) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.pitch, on: self)
            .store(in: &subscriptions)
        
        ahService
            .heading
            .map { $0.value.converted(to: .degrees).value }
            .receive(on: DispatchQueue.main)
            .assign(to: \.heading, on: self)
            .store(in: &subscriptions)
        
        ahService
            .location
            .map { [unowned self] value in
                guard let initialLocation = self.initialLocation else { return .init(value: 0, unit: .meters) }
                let distance = initialLocation.distance(from: .init(latitude: value.value.latitude, longitude: value.value.longitude))
                return .init(value: distance, unit: .meters)
            }
            .assign(to: \.distanceFromInitialLocation, on: self)
            .store(in: &subscriptions)
        
        machineStateService
            .speed
            .map { $0.value.converted(to: .metersPerSecond) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.speed, on: self)
            .store(in: &subscriptions)
        
        machineStateService
            .acceleration
            .map { $0.value.converted(to: .metersPerSecondSquared) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.acceleration, on: self)
            .store(in: &subscriptions)
        
        machineStateService
            .machineState
            .map { $0.value.state }
            .receive(on: DispatchQueue.main)
            .assign(to: \.state, on: self)
            .store(in: &subscriptions)
        
        machineStateService
            .altitude
            .map { $0.value.converted(to: .meters) }
            .receive(on: DispatchQueue.main)
            .map { [unowned self] value in
                .init(value: max(0, value.value - (self.zeroAltitude ?? 0)), unit: .meters)
            }
            .assign(to: \.qfe, on: self)
            .store(in: &subscriptions)

        
        Publishers.CombineLatest3(
            machineStateService.machineState.removeDuplicates(),
            machineStateService.speed.removeDuplicates(),
            machineStateService.altitude.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (info, speed, altitude) in
                guard info.value.isLaunching || info.value.state == .completed,
                      let tof = info.value.takeOffAltitude else {
                    self.importantAltitudes = Constants.importantAltitudes
                    return
                }
                
                if info.value.state == .takingOff {
                    self.takingOffDate = self.takingOffDate ?? Date()
                }
                
                if let first = self.importantAltitudes.first {
                    let relativeFirstAltitude = first + tof.value
                    
                    if altitude.value > relativeFirstAltitude {
                        let relativeAltitude = altitude.value - tof.value
                        self.say("\(Int(relativeAltitude.converted(to: .meters).value))")
                        self.importantAltitudes.removeFirst()
                        return
                    }
                }

                if info.value.state == .maxSpeedReached && self.lastSayMaxSpeedReached == nil {
                    self.lastSayMaxSpeedReached = Date()
                    self.say("meno")
                    return
                }
                
                if info.value.state == .minSpeedReached {
                    self.lastSayMaxSpeedReached = nil
                }
                
                if info.value.state == .completed, let maxAltitude = info.value.maxAltitude, self.lastSayQFE == nil {
                    self.lastSayQFE = Date()

                    let relativeAltitude = maxAltitude.value - tof.value
                    self.say("Max \(Int(relativeAltitude.converted(to: .meters).value))")
                }
                
//                switch info.value.state {
//                case .waiting: ()
//                case .takingOff:
//                    self.takingOffDate = self.takingOffDate ?? Date()
//                    
//                    if self.lastSayMin == nil {
//                        self.lastSayMin = Date()
//                        self.say("Min", speedMultiplier: 0.4)
//                    }
//                case .minSpeedReached:
//                    if self.lastSayMinSpeed == nil {
//                        self.lastSayMinSpeed = Date()
//                        self.lastSayMinSpeedLost = nil
//                        self.lastSayMaxSpeedReached = nil
//                        self.say("\(Int(speed.value.converted(to: .kilometersPerHour).value))")
//                    }
//                
//                case .minSpeedLost:
//                    if self.lastSayMinSpeedLost == nil {
//                        self.lastSayMinSpeedLost = Date()
//                        self.lastSayMinSpeed = nil
//                        self.say("\(Int(speed.value.converted(to: .kilometersPerHour).value))")
//                    }
//
//                case .maxSpeedReached:
//                    if self.lastSayMaxSpeedReached == nil {
//                        self.lastSayMaxSpeedReached = Date()
//                        self.lastSayMinSpeed = nil
//                        self.say("\(Int(speed.value.converted(to: .kilometersPerHour).value))")
//                    }
//                    
//                case .aborted, .completed: ()
//                }
            }
            .store(in: &subscriptions)

        Publishers.CombineLatest3(
            machineStateService.machineState.removeDuplicates(),
            machineStateService.altitude.removeDuplicates(),
            ahService.location.removeDuplicates()
        )
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (info, altitude, location) in
                if info.value.state == .waiting {
                    self.zeroAltitude = altitude.value.value
                    self.initialLocation = CLLocation(latitude: location.value.latitude, longitude: location.value.longitude)
                }
            
                switch info.value.state {
                case .waiting:
                    self.altitudeHistory.append(max(0, altitude.value.value - (self.zeroAltitude ?? 0)))
                    self.altitudeHistory = self.altitudeHistory.suffix(10)
                
                default:
                    self.altitudeHistory.append(max(0, altitude.value.value - (self.zeroAltitude ?? 0)))
                    self.altitudeHistory = self.altitudeHistory.suffix(1024)
                }
            }
            .store(in: &subscriptions)
        
        Publishers.CombineLatest(
            ahService.recordState,
            machineStateService.machineState
        )
            .throttle(for: .seconds(10), scheduler: RunLoop.main, latest: true)
            .sink { [unowned self](state, machine) in
                if self.record == false { return }
                guard let takeOffTime = machine.value.takeOffAltitude?.timestamp,
                      let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

                var trimmed = state.prefix(interval: takeOffTime.relativeTimeInterval - 20)
                guard !trimmed.pitch.isEmpty else { return }
                
                if let completionTime = machine.value.finalAltitude?.timestamp {
                    trimmed = trimmed.suffix(interval: completionTime.relativeTimeInterval + 20)
                }
                
                trimmed = trimmed.normalize()

                let recordDate = Date(dataPoint: takeOffTime.relativeTimeInterval)
                let filename = recordDate.localizedString + ".json"
                let fileURL = documentsDirectory.appendingPathComponent(filename)

                if let data = try? JSONEncoder().encode(trimmed) {
                    try? data.write(to: fileURL)
                    print("Dumped in \(fileURL)")
                }
            }
            .store(in: &subscriptions)

    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    func reset() {
        zeroAltitude = nil
        ahService?.reset()
    }
    
    func resetMachineState() {
        zeroAltitude = nil
        takingOffDate = nil
        altitudeHistory.removeAll()
        machineStateService?.reset()
        lastSayQFE = nil
    }
    
    func stop() {
        subscriptions.removeAll()
    }
    
    func say(_ string: String, speedMultiplier: Float? = 0.6) {
        let speechUtterance = AVSpeechUtterance(string: string)
        if let speedMultiplier = speedMultiplier {
            speechUtterance.rate = (AVSpeechUtteranceMinimumSpeechRate + AVSpeechUtteranceMaximumSpeechRate) * speedMultiplier
        }
        speechUtterance.voice = AVSpeechSynthesisVoice()
        Constants.synthesizer.speak(speechUtterance)
        lasSayString = string
        print("Say \(string)")
    }
}
