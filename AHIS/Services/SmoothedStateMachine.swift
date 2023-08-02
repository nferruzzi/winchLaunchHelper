//
//  SmoothedStateMachine.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import Foundation
import CoreLocation
import Combine


enum MachineState {
    case acceleration
    case constantSpeed
    case deceleration
}


protocol MachineStateProtocol {
    var speed: AnyPublisher<CLLocationSpeed, Never> { get }
    var acceleration: AnyPublisher<CLLocationSpeed, Never> { get }
    var machineState: AnyPublisher<MachineState, Never> { get }
}


final class SpeedProcessor {
    enum Constants {
        static let windowSize: Int = 10
        static let accelerationThreshold: CLLocationSpeed = 0.5 /// in m/s^2
        static let throttleSeconds: Double = 0.1
    }
    
    var speedPublisher: AnyPublisher<(Date, CLLocationSpeed), Never>

    private var lastPublishedTime: Date?
    private var speeds: [CLLocationSpeed] = []

    lazy var smoothedSpeedPublisher: some Publisher<CLLocationSpeed, Never> = {
        speedPublisher
            .filter { [unowned self] timestamp, _ in
                if let lastPublishedTime = self.lastPublishedTime, timestamp.timeIntervalSince(lastPublishedTime) < 0.1 {
                    return false
                }
                self.lastPublishedTime = timestamp
                return true
            }
            .map { [unowned self] (_, speed) in
                self.speeds.append(speed)
                if self.speeds.count > Constants.windowSize {
                    self.speeds.removeFirst()
                }
                
                return calculateMovingAverage()
            }
            .share()
    }()

    lazy var accelerationPublisher: some Publisher<CLLocationSpeed, Never> = {
        Publishers.CombineLatest(
            smoothedSpeedPublisher.dropFirst(),
            smoothedSpeedPublisher
        )
            .map { prev, current in
                (current - prev) / Constants.throttleSeconds
            }
            .share()
    }()
    
    lazy var statePublisher: some Publisher<MachineState, Never> = {
        accelerationPublisher
            .map { acceleration in
                if acceleration > Constants.accelerationThreshold {
                    return .acceleration
                } else if acceleration < -Constants.accelerationThreshold {
                    return .deceleration
                } else {
                    return .constantSpeed
                }
            }
            .share()
    }()
        
    init<SpeedPublisher: Publisher<(Date, CLLocationSpeed), Never>>(speedPublisher: SpeedPublisher) {
        /// Assuming 10 Hz sampling rate
        self.speedPublisher = speedPublisher
            .eraseToAnyPublisher()
    }
        
    private func calculateMovingAverage() -> CLLocationSpeed {
        speeds.reduce(0, +) / CLLocationSpeed(speeds.count)
    }
}


extension SpeedProcessor: MachineStateProtocol {
    var speed: AnyPublisher<CLLocationSpeed, Never> {
        smoothedSpeedPublisher.eraseToAnyPublisher()
    }

    var acceleration: AnyPublisher<CLLocationSpeed, Never> {
        accelerationPublisher.eraseToAnyPublisher()
    }

    var machineState: AnyPublisher<MachineState, Never> {
        statePublisher.eraseToAnyPublisher()
    }
}
