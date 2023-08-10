//
//  MachineStateService.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import Foundation
import CoreLocation
import Combine


enum MachineState: String {
    case waiting
    case acceleration
    case constantSpeed
    case deceleration
    case completed
}


typealias DataPointMachineState = DataPoint<MachineState>

protocol MachineStateProtocol {
    var speed: AnyPublisher<DataPointSpeed, Never> { get }
    var acceleration: AnyPublisher<DataPointAcceleration, Never> { get }
    var machineState: AnyPublisher<DataPointMachineState, Never> { get }
}


final class MachineStateService {
    enum Constants {
        static let windowSize: Int = 10
        static let accelerationThreshold = Measurement<UnitAcceleration>(value: 0.5, unit: .metersPerSecondSquared)
        static let speedThreshold = Measurement<UnitSpeed>(value: 20, unit: .kilometersPerHour)

        // CoreLocation generates just 1 msg per second, we interpolate the speed to have more
        static let throttleSeconds: Double = 0.1
    }
    
    var speedPublisher: AnyPublisher<DataPointSpeed, Never>

    private var lastPublishedTime: Date?
    private var speeds: [CLLocationSpeed] = []
    private var notStoppedTime: Date?
    
    /// Data from core location are too sparse, a moving average would simply add too much delay
    lazy var smoothedSpeedPublisher: some Publisher<DataPointSpeed, Never> = {
        interpolatedSpeedPublisher
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
//            .map(\.1)
            .share()
    }()

    lazy var accelerationPublisher: some Publisher<DataPointAcceleration, Never> = {
        smoothedSpeedPublisher
            .zip(smoothedSpeedPublisher.dropFirst())
            .map { prev, current in
                precondition(prev.date.timeIntervalSince1970 <= current.date.timeIntervalSince1970)
                let acceleration = (current.value.value - prev.value.value) / Constants.throttleSeconds
                return .init(date: current.date, value: .init(value: acceleration, unit: .metersPerSecondSquared))
            }
            .share()
    }()
    
    lazy var statePublisher: some Publisher<DataPointMachineState, Never> = {
        Publishers.CombineLatest(
            speed,
            acceleration
        )
            .map { speed, acceleration in
                guard speed.value > Constants.speedThreshold else {
                    return .init(date: speed.date, value: .waiting)
                }
                
                if acceleration.value > Constants.accelerationThreshold {
                    return .init(date: speed.date, value: .acceleration)
                } else if acceleration.value < Constants.accelerationThreshold * -1.0 {
                    return .init(date: speed.date, value: .deceleration)
                } else {
                    return .init(date: speed.date, value: .constantSpeed)
                }
            }
            .share()
    }()
    
    lazy var interpolatedSpeedPublisher: some Publisher<DataPointSpeed, Never> = {
        Publishers.CombineLatest(
            Timer.publish(every: Constants.throttleSeconds, on: RunLoop.main, in: .default).autoconnect(),
            speedPublisher.zip(speedPublisher.dropFirst())
        )
        .map { timer, speeds -> DataPointSpeed in
            let prev = speeds.0
            let current = speeds.1
            
            let interpolate = Double.interpolate(t1: prev.date.timeIntervalSince1970,
                                                 v1: prev.value.value,
                                                 t2: current.date.timeIntervalSince1970,
                                                 v2: current.value.value,
                                                 t: timer.timeIntervalSince1970)

            return .init(date: timer, value: .init(value: interpolate, unit: .metersPerSecond))
        }
        .share()
    }()
        
    init<SpeedPublisher: Publisher<DataPointSpeed, Never>>(speedPublisher: SpeedPublisher) {
        self.speedPublisher = speedPublisher
            .eraseToAnyPublisher()
    }
        
    private func calculateMovingAverage() -> CLLocationSpeed {
        speeds.reduce(0, +) / CLLocationSpeed(speeds.count)
    }
}


extension MachineStateService: MachineStateProtocol {
    var speed: AnyPublisher<DataPointSpeed, Never> {
        smoothedSpeedPublisher
            .eraseToAnyPublisher()
    }

    var acceleration: AnyPublisher<DataPointAcceleration, Never> {
        accelerationPublisher
            .eraseToAnyPublisher()
    }

    var machineState: AnyPublisher<DataPointMachineState, Never> {
        statePublisher.eraseToAnyPublisher()
    }
}
