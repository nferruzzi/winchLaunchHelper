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
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    private var ahService: DeviceMotionProtocol?
    private let machineStateService: MachineStateProtocol?
    
    @Published private(set) var roll: Int = 0
    @Published private(set) var pitch: Int = 0
    @Published private(set) var heading: Double = 0
    
    @Published private(set) var speed: DataPointSpeed.ValueType = .init(value: 0, unit: .metersPerSecond)
    @Published private(set) var gpsSpeed: DataPointSpeed.ValueType = .init(value: 0, unit: .metersPerSecond)
    
    @Published private(set) var acceleration: DataPointAcceleration.ValueType = .init(value: 0, unit: .metersPerSecondSquared)
    @Published private(set) var state: MachineState = .waiting
    @Published private(set) var lasSayString: String = ""
    @Published private(set) var altitude: [Double] = []
    
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
    
    @Published var record: Bool {
        didSet {
            ahService?.record = record
        }
    }
    

    private var lastSayMin: Date?
    private var lastSayMinSpeed: Date?
    private var lastSayMinSpeedLost: Date?
    private var lastSayMaxSpeedReached: Date?

    private var zeroAltitude: Double?
    
    init(ahService: DeviceMotionProtocol? = nil,
         machineStateService: MachineStateProtocol? = nil) {
        
        self.ahService = ahService
        self.machineStateService = machineStateService
        self.minSpeed = ahService?.minSpeed ?? .init(value: 0, unit: .kilometersPerHour)
        self.maxSpeed = ahService?.maxSpeed ?? .init(value: 0, unit: .kilometersPerHour)
        self.record = ahService?.record ?? false
        
        guard let machineStateService = machineStateService,
              let ahService = ahService else { return }
        
        ahService
            .speed
            .map { $0.value.converted(to: .metersPerSecond) }
            .receive(on: DispatchQueue.main)
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
        
        ahService.heading
            .map { $0.value.converted(to: .degrees).value }
            .receive(on: DispatchQueue.main)
            .assign(to: \.heading, on: self)
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
        
        
        Publishers.CombineLatest(machineStateService.machineState.removeDuplicates(),
                                 ahService.speed.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (info, speed) in
                switch info.value.state {
                case .waiting: ()
                case .takingOff:
                    if self.lastSayMin == nil {
                        self.lastSayMin = Date()
                        self.say("Min", speedMultiplier: 0.4)
                    }
                case .minSpeedReached:
                    if self.lastSayMinSpeed == nil {
                        self.lastSayMinSpeed = Date()
                        self.lastSayMinSpeedLost = nil
                        self.lastSayMaxSpeedReached = nil
                        self.say("\(Int(speed.value.converted(to: .kilometersPerHour).value))")
                    }
                
                case .minSpeedLost:
                    if self.lastSayMinSpeedLost == nil {
                        self.lastSayMinSpeedLost = Date()
                        self.lastSayMinSpeed = nil
                        self.say("\(Int(speed.value.converted(to: .kilometersPerHour).value))")
                    }

                case .maxSpeedReached:
                    if self.lastSayMaxSpeedReached == nil {
                        self.lastSayMaxSpeedReached = Date()
                        self.lastSayMinSpeed = nil
                        self.say("\(Int(speed.value.converted(to: .kilometersPerHour).value))")
                    }
                }
            }
            .store(in: &subscriptions)

        Publishers.CombineLatest(machineStateService.machineState.removeDuplicates(),
                                 ahService.altitude.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (info, altitude) in
                if info.value.state == .waiting {
                    self.zeroAltitude = altitude.value.value - 2
                } else {
                    self.zeroAltitude = self.zeroAltitude ?? (altitude.value.value - 2)
                }
            
                switch info.value.state {
                case .waiting:
                    self.altitude.append(max(0, altitude.value.value - (self.zeroAltitude ?? 0)))
                    self.altitude = self.altitude.suffix(30)
                
                default:
                    self.altitude.append(max(0, altitude.value.value - (self.zeroAltitude ?? 0)))
                    self.altitude = self.altitude.suffix(1024)
                }
            }
            .store(in: &subscriptions)
    }
    
    func reset() {
        zeroAltitude = nil
        ahService?.reset()
    }
    
    func say(_ string: String, speedMultiplier: Float = 0.6) {
        let speechUtterance = AVSpeechUtterance(string: string)
        speechUtterance.rate = (AVSpeechUtteranceMinimumSpeechRate + AVSpeechUtteranceMaximumSpeechRate) * speedMultiplier
        speechUtterance.voice = AVSpeechSynthesisVoice()
        Constants.synthesizer.speak(speechUtterance)
        lasSayString = string
        print("Say \(string)")
    }
}
