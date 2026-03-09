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

private extension Float {
    func nonZeroOrDefault(_ defaultValue: Float) -> Float {
        self == 0 ? defaultValue : self
    }
}


final class AHServiceViewModel: ObservableObject {
    enum Constants {
        static let synthesizer = AVSpeechSynthesizer()
        static let defaultAltitudes: [Int] = [1, 20, 50, 100, 200, 250]
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

    @Published private(set) var info: DataPointMachineState = .init(timestamp: .relative(0), value: .init(state: .waiting, stateTimestamp: .relative(0)))
    var state: MachineState { info.value.state }

    @Published private(set) var lasSayString: String = ""
    @Published private(set) var altitudeHistory: [Double] = []
        
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
    
    @Published var importantAltitudes: [DataPointLength.ValueType] = []

    /// Configured altitude callouts in meters, persisted via UserDefaults
    @Published var configuredAltitudes: [Int] = (UserDefaults.standard.array(forKey: "configuredAltitudes") as? [Int]) ?? Constants.defaultAltitudes {
        didSet { UserDefaults.standard.set(configuredAltitudes, forKey: "configuredAltitudes") }
    }

    var altitudesAsMeasurements: [DataPointLength.ValueType] {
        configuredAltitudes.sorted().map { .init(value: Double($0), unit: .meters) }
    }

    // MARK: - Alert configuration
    @Published var speechRate: Float = UserDefaults.standard.float(forKey: "speechRate").nonZeroOrDefault(0.45) {
        didSet { UserDefaults.standard.set(speechRate, forKey: "speechRate") }
    }
    @Published var wingDropMessage: String = UserDefaults.standard.string(forKey: "wingDropMessage") ?? String(localized: "wing", comment: "Default wing drop voice callout message") {
        didSet { UserDefaults.standard.set(wingDropMessage, forKey: "wingDropMessage") }
    }
    @Published var minSpeedMessage: String = UserDefaults.standard.string(forKey: "minSpeedMessage") ?? String(localized: "minimum", comment: "Default min speed reached voice callout message") {
        didSet { UserDefaults.standard.set(minSpeedMessage, forKey: "minSpeedMessage") }
    }
    @Published var minSpeedLostMessage: String = UserDefaults.standard.string(forKey: "minSpeedLostMessage") ?? String(localized: "plus", comment: "Default min speed lost voice callout message") {
        didSet { UserDefaults.standard.set(minSpeedLostMessage, forKey: "minSpeedLostMessage") }
    }
    @Published var maxSpeedMessage: String = UserDefaults.standard.string(forKey: "maxSpeedMessage") ?? String(localized: "minus", comment: "Default overspeed voice callout message") {
        didSet { UserDefaults.standard.set(maxSpeedMessage, forKey: "maxSpeedMessage") }
    }
    @Published var altitudeCalloutsEnabled: Bool = UserDefaults.standard.object(forKey: "altitudeCalloutsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(altitudeCalloutsEnabled, forKey: "altitudeCalloutsEnabled") }
    }
    @Published var minSpeedCalloutEnabled: Bool = UserDefaults.standard.object(forKey: "minSpeedCalloutEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(minSpeedCalloutEnabled, forKey: "minSpeedCalloutEnabled") }
    }
    @Published var maxSpeedCalloutEnabled: Bool = UserDefaults.standard.object(forKey: "maxSpeedCalloutEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(maxSpeedCalloutEnabled, forKey: "maxSpeedCalloutEnabled") }
    }
    @Published var wingDropCalloutEnabled: Bool = UserDefaults.standard.object(forKey: "wingDropCalloutEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(wingDropCalloutEnabled, forKey: "wingDropCalloutEnabled") }
    }
    @Published var maxAltitudeCalloutEnabled: Bool = UserDefaults.standard.object(forKey: "maxAltitudeCalloutEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(maxAltitudeCalloutEnabled, forKey: "maxAltitudeCalloutEnabled") }
    }

    private var lastSayMin: Date?
    private var lastSayMinSpeed: Date?
    private var lastSayMinSpeedLost: Date?
    private var lastSayMaxSpeedReached: Date?
    private var lastSayQFE: Date?
    /// Wing drop: announced once per launch, reset on waiting
    private var wingDropAnnounced: Bool = false
    /// Roll threshold in degrees for wing drop detection
    static let wingDropThresholdDegrees: Double = 15.0
    /// Wing drop is monitored only in these early launch phases
    static let wingDropMonitoredStates: Set<MachineState> = [.takingOff, .minSpeedReached, .minSpeedLost]

    /// Pure function for wing drop detection — extracted for testability
    static func shouldAnnounceWingDrop(
        rollDegrees: Double,
        state: MachineState,
        alreadyAnnounced: Bool,
        thresholdDegrees: Double = wingDropThresholdDegrees,
        monitoredStates: Set<MachineState> = wingDropMonitoredStates
    ) -> Bool {
        !alreadyAnnounced
            && monitoredStates.contains(state)
            && abs(rollDegrees) > thresholdDegrees
    }

    private var zeroAltitude: Double?
    private var initialLocation: CLLocation?

    private var recordTime: DataPointTimeInterval?
    
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
            .map { $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.info, on: self)
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

        
        // Wing drop detection: monitor roll at full sensor rate during early launch phases
        ahService
            .roll
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] rollDataPoint in
                let rollDegrees = rollDataPoint.value.converted(to: .degrees).value
                guard self.wingDropCalloutEnabled,
                      Self.shouldAnnounceWingDrop(
                          rollDegrees: rollDegrees,
                          state: self.state,
                          alreadyAnnounced: self.wingDropAnnounced
                      ) else { return }
                self.wingDropAnnounced = true
                self.say(self.wingDropMessage)
            }
            .store(in: &subscriptions)

        Publishers.CombineLatest3(
            machineStateService.machineState.removeDuplicates(),
            machineStateService.speed.removeDuplicates(),
            machineStateService.altitude.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (info, speed, altitude) in
                guard info.value.isLaunching || info.value.state == .completed,
                      let tof = info.value.takeOffAltitude else {
                    self.importantAltitudes = self.altitudesAsMeasurements
                    return
                }
                                
                if self.altitudeCalloutsEnabled, let first = self.importantAltitudes.first {
                    let relativeFirstAltitude = first + tof.value

                    if altitude.value > relativeFirstAltitude {
                        let relativeAltitude = altitude.value - tof.value
                        self.say("\(Int(relativeAltitude.converted(to: .meters).value))")
                        self.importantAltitudes.removeFirst()
                        return
                    }
                }

                if self.minSpeedCalloutEnabled, info.value.state == .minSpeedReached, self.lastSayMinSpeed == nil {
                    self.lastSayMinSpeed = Date()
                    self.say(self.minSpeedMessage)
                    return
                }

                if self.minSpeedCalloutEnabled, info.value.state == .minSpeedLost, self.lastSayMinSpeedLost == nil {
                    self.lastSayMinSpeedLost = Date()
                    self.lastSayMaxSpeedReached = nil
                    self.say(self.minSpeedLostMessage)
                    return
                }

                if info.value.state == .minSpeedReached {
                    self.lastSayMinSpeedLost = nil
                    self.lastSayMaxSpeedReached = nil
                }

                if self.maxSpeedCalloutEnabled, info.value.state == .maxSpeedReached, self.lastSayMaxSpeedReached == nil {
                    self.lastSayMaxSpeedReached = Date()
                    self.say(self.maxSpeedMessage)
                    return
                }

                if self.maxAltitudeCalloutEnabled, info.value.state == .completed, let maxAltitude = info.value.maxAltitude, self.lastSayQFE == nil {
                    self.lastSayQFE = Date()

                    let relativeAltitude = maxAltitude.value - tof.value
                    let maxPrefix = String(localized: "Max ", comment: "Prefix for max altitude speech callout")
                    self.say("\(maxPrefix)\(Int(relativeAltitude.converted(to: .meters).value))")
                }
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
                    self.wingDropAnnounced = false
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
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)
            .sink { [unowned self](state, machine) in
                guard self.record == true,
                      let takeOffTime = machine.value.takeOffAltitude?.timestamp,
                      machine.value.state == .completed || machine.value.state == .aborted,
                      takeOffTime != self.recordTime,
                      let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                
                self.recordTime = takeOffTime
                
                var trimmed = state.prefix(interval: takeOffTime.relativeTimeInterval - 30)
                guard !trimmed.pitch.isEmpty else { return }
                
                if let completionTime = machine.value.finalAltitude?.timestamp {
                    trimmed = trimmed.suffix(interval: completionTime.relativeTimeInterval + 30)
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
        altitudeHistory.removeAll()
        machineStateService?.reset()
        lastSayQFE = nil
        wingDropAnnounced = false
    }
    
    func stop() {
        subscriptions.removeAll()
    }
    
    func say(_ string: String) {
        let speechUtterance = AVSpeechUtterance(string: string)
        speechUtterance.rate = speechRate
        speechUtterance.voice = AVSpeechSynthesisVoice()
        Constants.synthesizer.speak(speechUtterance)
        lasSayString = string
        print("Say \(string)")
    }
}
