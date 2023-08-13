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
        /// ask13 
        static let minSpeed = Measurement<UnitSpeed>(value: 70, unit: .kilometersPerHour)
        static let maxSpeed = Measurement<UnitSpeed>(value: 110, unit: .kilometersPerHour)
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    private let ahService: DeviceMotionProtocol?
    private let machineStateService: MachineStateProtocol?
    
    @Published private(set) var roll: Int = 0
    @Published private(set) var pitch: Int = 0
    @Published private(set) var heading: Double = 0
    
    @Published private(set) var speed: DataPointSpeed.ValueType = .init(value: 0, unit: .metersPerSecond)
    @Published private(set) var acceleration: DataPointAcceleration.ValueType = .init(value: 0, unit: .metersPerSecondSquared)
    @Published private(set) var state: MachineState = .waiting
    @Published private(set) var lasSayString: String = ""
    @Published private(set) var altitude: [Double] = []
    
    private var lastSayMinAcceleration: Date?
    private var lastSayMaxAcceleration: Date?
    private var lastSayMinDeceleration: Date?

    private var zeroAltitude: Double?
    
    init(ahService: DeviceMotionProtocol? = nil,
         machineStateService: MachineStateProtocol? = nil) {
        
        self.ahService = ahService
        self.machineStateService = machineStateService
        
        guard let machineStateService = machineStateService,
              let ahService = ahService else { return }

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
                                 machineStateService.speed.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (info, speed) in
                if info.value.state == .acceleration {
                    self.lastSayMinDeceleration = nil
                    
                    if speed.value > Constants.minSpeed, self.lastSayMinAcceleration == nil {
                        self.lastSayMinAcceleration = Date()
                        self.say("+\(Int(Constants.minSpeed.value))")
                    }
                    if speed.value > Constants.maxSpeed, self.lastSayMaxAcceleration == nil {
                        self.lastSayMaxAcceleration = Date()
                        self.say("+\(Int(Constants.maxSpeed.value))")
                    }
                }
                
                if info.value.state == .deceleration {
                    self.lastSayMinAcceleration = nil
                    self.lastSayMaxAcceleration = nil
                    
                    if speed.value < Constants.minSpeed, self.lastSayMinDeceleration == nil {
                        self.lastSayMinDeceleration = Date()
                        self.say("-\(Int(Constants.minSpeed.value))")
                    }
                }
            }
            .store(in: &subscriptions)

        Publishers.CombineLatest(machineStateService.machineState.removeDuplicates(),
                                 ahService.altitude.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (info, altitude) in
                guard info.value.state != .completed else { return }
                
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
    
    func say(_ string: String) {
        let speechUtterance = AVSpeechUtterance(string: string)
        speechUtterance.rate = (AVSpeechUtteranceMinimumSpeechRate + AVSpeechUtteranceMaximumSpeechRate) * 0.6
        speechUtterance.voice = AVSpeechSynthesisVoice()
        Constants.synthesizer.speak(speechUtterance)
        lasSayString = string
        print("Say \(string)")
    }
}
