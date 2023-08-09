//
//  SmoothedStateMachine.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import Foundation
import CoreLocation
import Combine


enum MachineState: String {
    case acceleration
    case constantSpeed
    case deceleration
}


protocol MachineStateProtocol {
    var speed: AnyPublisher<Measurement<UnitSpeed>, Never> { get }
    var acceleration: AnyPublisher<Measurement<UnitAcceleration>, Never> { get }
    var machineState: AnyPublisher<MachineState, Never> { get }
}


final class SpeedProcessor {
    enum Constants {
        static let windowSize: Int = 10
        static let accelerationThreshold: CLLocationSpeed = 0.5 /// in m/s^2
        static let throttleSeconds: Double = 1.0 // CoreLocation generates just 1 msg per second
    }
    
    var speedPublisher: AnyPublisher<(Date, CLLocationSpeed), Never>

    private var lastPublishedTime: Date?
    private var speeds: [CLLocationSpeed] = []

    /// Data from core location are too sparse, a moving average would simply add too much delay
    lazy var smoothedSpeedPublisher: some Publisher<CLLocationSpeed, Never> = {
        speedPublisher
//            .map { [unowned self] (timestamp, speed) -> (Date, Double) in
//                self.speeds.append(speed)
//                if self.speeds.count > Constants.windowSize {
//                    self.speeds.removeFirst()
//                }
//
//                return (timestamp, calculateMovingAverage())
//            }
//            .filter { [unowned self] timestamp, _ in
//                if let lastPublishedTime = self.lastPublishedTime, timestamp.timeIntervalSince(lastPublishedTime) < 0.1 {
//                    return false
//                }
//                self.lastPublishedTime = timestamp
//                return true
//            }
            .map(\.1)
            .share()
    }()

    lazy var accelerationPublisher: some Publisher<CLLocationSpeed, Never> = {
        smoothedSpeedPublisher
            .zip(smoothedSpeedPublisher.dropFirst())
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
        self.speedPublisher = speedPublisher
            .eraseToAnyPublisher()
    }
        
    private func calculateMovingAverage() -> CLLocationSpeed {
        speeds.reduce(0, +) / CLLocationSpeed(speeds.count)
    }
}


extension SpeedProcessor: MachineStateProtocol {
    var speed: AnyPublisher<Measurement<UnitSpeed>, Never> {
        smoothedSpeedPublisher
            .map { .init(value: $0, unit: .metersPerSecond) }
            .eraseToAnyPublisher()
    }

    var acceleration: AnyPublisher<Measurement<UnitAcceleration>, Never> {
        accelerationPublisher
            .map { .init(value: $0, unit: .metersPerSecondSquared) }
            .eraseToAnyPublisher()
    }

    var machineState: AnyPublisher<MachineState, Never> {
        statePublisher.eraseToAnyPublisher()
    }
}
