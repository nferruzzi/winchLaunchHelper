//
//  MachineStateService.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import Foundation
import CoreLocation
import Combine


enum MachineState: String, Codable {
    case waiting
    case acceleration
    case constantSpeed
    case deceleration
    case completed
}

struct MachineInfo: Equatable, Codable {
    let state: MachineState
    let instantSpeed: DataPointSpeed
    let instantAcceleration: DataPointAcceleration
}


typealias DataPointMachineState = DataPoint<MachineInfo>

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
        static let throttleSeconds: Double = 0.01
    }
    
    var speedPublisher: AnyPublisher<DataPointSpeed, Never>
    var userAccelerationPublisher: AnyPublisher<DataPointUserAcceleration, Never>

    private var lastPublishedTime: Date?
    private var speeds: [DataPointSpeed] = []
    private var notStoppedTime: Date?
    private var lastPublishedSmoothedTime: Date?
    private var ekf = ExtendedKalmanFilter()

    lazy var interpolatedSpeedPublisher: some Publisher<DataPointSpeed, Never> = {
        speedPublisher.map { [unowned self] dataPoint in
            self.ekf.updateWithVelocity(velocityMeasurement: dataPoint.value.value)
            return self.accelerationPublisher
        }
        .switchToLatest()
        .map { [unowned self] dataPoint in
            self.ekf.updateWithAcceleration(accelerationValue: dataPoint.value.value)
            self.ekf.predictState()
            
            let speed = self.ekf.velocity
            return DataPointSpeed(timestamp: dataPoint.timestamp, value: .init(value: speed, unit: .metersPerSecond))
        }
//        .print("is")
        .share()
        
//
//        Publishers.CombineLatest(
//            Timer.publish(every: Constants.throttleSeconds, on: RunLoop.main, in: .default).autoconnect(),
//            accelerationPublisher
//        )
//        .compactMap { [unowned self] timer, speeds -> DataPointSpeed? in
//            guard timer != self.lastPublishedSmoothedTime else { return nil }
//            self.lastPublishedSmoothedTime = timer
//
//            let prev = speeds.0
//            let current = speeds.1
//
//            let t = timer.timeRelativeToDataPointInterval
//            let interpolate = Double.interpolate(t1: prev.timestamp.relativeTimeInterval,
//                                                 v1: prev.value.value,
//                                                 t2: current.timestamp.relativeTimeInterval,
//                                                 v2: current.value.value,
//                                                 t: t)
//
////            debugPrint(timer.timeIntervalSince1970, t, prev.value.value, current.value.value, " -> ", interpolate)
//            let value = DataPointSpeed(timestamp: .relative(t),
//                                       value: .init(value: interpolate, unit: .metersPerSecond))
//            return value
//        }
//        .share()
    }()
        
    /// Data from core location are too sparse, a moving average would simply add too much delay
    lazy var smoothedSpeedPublisher: some Publisher<DataPointSpeed, Never> = {
        interpolatedSpeedPublisher
//            .map { [unowned self] speed -> DataPointSpeed in
//                self.speeds.append(speed)
//                if self.speeds.count > Constants.windowSize {
//                    self.speeds.removeFirst()
//                }
//
//                return .init(date: speed.date, value: .init(value: calculateMovingAverage(), unit: .metersPerSecond))
//            }
//            .filter { [unowned self] speed in
//                if let lastPublishedTime = self.lastPublishedTime, speed.date.timeIntervalSince(lastPublishedTime) < 0.1 {
//                    return false
//                }
//                self.lastPublishedTime = speed.date
//                return true
//            }
            .share()
    }()

    lazy var accelerationPublisher: some Publisher<DataPointAcceleration, Never> = {
        userAccelerationPublisher.map { dataPoint in
            let measure = Measurement<UnitAcceleration>(value: -dataPoint.value.z, unit: .gravity)
            return .init(timestamp: dataPoint.timestamp, value: measure.converted(to: .metersPerSecondSquared))
        }
//        .print("Acc")
        .share()
//        smoothedSpeedPublisher
//            .zip(smoothedSpeedPublisher.dropFirst())
//            .map { prev, current in
//                precondition(prev.timestamp <= current.timestamp)
//                let acceleration = (current.value.value - prev.value.value) / Constants.throttleSeconds
//                return .init(timestamp: current.timestamp, value: .init(value: acceleration, unit: .metersPerSecondSquared))
//            }
//            .share()
        
    }()
    
    lazy var statePublisher: some Publisher<DataPointMachineState, Never> = {
        Publishers.CombineLatest(
            smoothedSpeedPublisher,
            accelerationPublisher
        )
            .map { speed, acceleration in
                guard speed.value > Constants.speedThreshold else {
                    return .init(timestamp: speed.timestamp, value: .init(state: .waiting, instantSpeed: speed, instantAcceleration: acceleration))
                }
                
                if acceleration.value > Constants.accelerationThreshold {
                    return .init(timestamp: speed.timestamp, value: .init(state: .acceleration, instantSpeed: speed, instantAcceleration: acceleration))
                } else if acceleration.value < Constants.accelerationThreshold * -1.0 {
                    return .init(timestamp: speed.timestamp, value: .init(state: .deceleration, instantSpeed: speed, instantAcceleration: acceleration))
                } else {
                    return .init(timestamp: speed.timestamp, value:  .init(state: .constantSpeed, instantSpeed: speed, instantAcceleration: acceleration))
                }
            }
//            .print("state")
            .share()
    }()
    
    init(speedPublisher: AnyPublisher<DataPointSpeed, Never>, userAccelerationPublisher: AnyPublisher<DataPointUserAcceleration, Never>) {
        self.speedPublisher = speedPublisher
        self.userAccelerationPublisher = userAccelerationPublisher
    }
        
    private func calculateMovingAverage() -> CLLocationSpeed {
        speeds.reduce(0, { $0 + $1.value.value }) / CLLocationSpeed(speeds.count)
    }
}


extension MachineStateService: MachineStateProtocol {
    var speed: AnyPublisher<DataPointSpeed, Never> {
        smoothedSpeedPublisher.eraseToAnyPublisher()
    }

    var acceleration: AnyPublisher<DataPointAcceleration, Never> {
        accelerationPublisher.eraseToAnyPublisher()
    }

    var machineState: AnyPublisher<DataPointMachineState, Never> {
        statePublisher.eraseToAnyPublisher()
    }
}
