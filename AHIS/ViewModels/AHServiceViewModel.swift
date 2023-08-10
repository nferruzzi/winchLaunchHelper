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
    
    private var lastSayMinAcceleration: Date?
    private var lastSayMaxAcceleration: Date?
    private var lastSayMinDeceleration: Date?
    
    init(ahService: DeviceMotionProtocol? = nil,
         machineStateService: MachineStateProtocol? = nil) {
        
        self.ahService = ahService
        self.machineStateService = machineStateService
        
        ahService?
            .roll
            .map { Int($0.value.converted(to: .degrees).value) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.roll, on: self)
            .store(in: &subscriptions)
        
        ahService?
            .pitch
            .map { Int($0.value.converted(to: .degrees).value) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.pitch, on: self)
            .store(in: &subscriptions)
        
        ahService?.heading
            .map { $0.value.converted(to: .degrees).value }
            .receive(on: DispatchQueue.main)
            .assign(to: \.heading, on: self)
            .store(in: &subscriptions)
        
        machineStateService?
            .speed
            .receive(on: DispatchQueue.main)
            .assign(to: \.speed, on: self)
            .store(in: &subscriptions)
        
        machineStateService?
            .acceleration
            .receive(on: DispatchQueue.main)
            .assign(to: \.acceleration, on: self)
            .store(in: &subscriptions)
        
        machineStateService?
            .machineState
            .receive(on: DispatchQueue.main)
            .assign(to: \.state, on: self)
            .store(in: &subscriptions)
        
        if let machineStateService = machineStateService {
            Publishers.CombineLatest(machineStateService.machineState.removeDuplicates(),
                                     machineStateService.speed.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (state, speed) in
                if state == .acceleration {
                    self.lastSayMinDeceleration = nil
                    
                    if speed > Constants.minSpeed, self.lastSayMinAcceleration == nil {
                        self.lastSayMinAcceleration = Date()
                        self.say("+\(Int(Constants.minSpeed.value))")
                    }
                    if speed > Constants.maxSpeed, self.lastSayMaxAcceleration == nil {
                        self.lastSayMaxAcceleration = Date()
                        self.say("+\(Int(Constants.maxSpeed.value))")
                    }
                }
                
                if state == .deceleration {
                    self.lastSayMinAcceleration = nil
                    self.lastSayMaxAcceleration = nil
                    
                    if speed < Constants.minSpeed, self.lastSayMinDeceleration == nil {
                        self.lastSayMinDeceleration = Date()
                        self.say("-\(Int(Constants.minSpeed.value))")
                    }
                }
            }
            .store(in: &subscriptions)
        }
    }
    
    func reset() {
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
