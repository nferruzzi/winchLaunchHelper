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
    
    case takingOff
    case minSpeedReached
    case minSpeedLost
    case maxSpeedReached
}

struct MachineInfo: Equatable, Codable {
    let state: MachineState
    let stateTimestamp: DataPointTimeInterval
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
        static let accelerationThreshold = Measurement<UnitAcceleration>(value: 1.0, unit: .metersPerSecondSquared)
        static let speedThreshold = Measurement<UnitSpeed>(value: 20, unit: .kilometersPerHour)

        // CoreLocation generates just 1 msg per second, we interpolate the speed to have more
        static let throttleSeconds: Double = 0.01
    }
    
    
    private var ahService: DeviceMotionProtocol
    private var lastPublishedTime: Date?
    private var speeds: [DataPointSpeed] = []
    private var notStoppedTime: Date?
    private var lastPublishedSmoothedTime: Date?
    private var ekf = ExtendedKalmanFilter()
    private var accelerations: [DataPointAcceleration] = []
    
    private var currentInfo: MachineInfo = .init(state: .waiting, stateTimestamp: .date(Date()))

    lazy var interpolatedSpeedPublisher: some Publisher<DataPointSpeed, Never> = {
        ahService.speed.map { [unowned self] dataPoint in
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
        .share()
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
        ahService.userAcceleration.map { dataPoint in
            let measure = Measurement<UnitAcceleration>(value: -dataPoint.value.z, unit: .gravity)
            return .init(timestamp: dataPoint.timestamp, value: measure.converted(to: .metersPerSecondSquared))
        }
        .share()
    }()
    
    lazy var smoothedAccelerationsPublisher: some Publisher<DataPointAcceleration, Never> = {
        accelerationPublisher
            .map { [unowned self] acceleration -> DataPointAcceleration in
                self.accelerations.append(acceleration)
                if self.accelerations.count > Constants.windowSize {
                    self.accelerations.removeFirst()
                }

                let movingAverage = accelerations.reduce(0, { $0 + $1.value.value }) / Double(accelerations.count)
                return .init(timestamp: acceleration.timestamp, value: .init(value: movingAverage, unit: .metersPerSecondSquared))
            }
//            .filter { [unowned self] speed in
//                if let lastPublishedTime = self.lastPublishedTime, speed.date.timeIntervalSince(lastPublishedTime) < 0.1 {
//                    return false
//                }
//                self.lastPublishedTime = speed.date
//                return true
//            }
            .share()
    }()
    
    lazy var statePublisher: some Publisher<DataPointMachineState, Never> = {
        Publishers.CombineLatest(
            smoothedSpeedPublisher,
            smoothedAccelerationsPublisher
        )
            .map { [unowned self] speed, acceleration in
                guard speed.value > Constants.speedThreshold else {
                    return .init(timestamp: speed.timestamp, value: .init(state: .waiting, stateTimestamp: speed.timestamp))
                }
                
                switch self.currentInfo.state {
                case .waiting:
                    return .init(timestamp: speed.timestamp, value: .init(state: .takingOff, stateTimestamp: speed.timestamp))

                case .takingOff:
                    if speed.value > ahService.minSpeed { return .init(timestamp: speed.timestamp, value: .init(state: .minSpeedReached, stateTimestamp: speed.timestamp)) }
                    return .init(timestamp: speed.timestamp, value: self.currentInfo)

                case .minSpeedReached:
                    if speed.value < ahService.minSpeed { return .init(timestamp: speed.timestamp, value: .init(state: .minSpeedLost, stateTimestamp: speed.timestamp)) }
                    if speed.value > ahService.maxSpeed { return .init(timestamp: speed.timestamp, value: .init(state: .maxSpeedReached, stateTimestamp: speed.timestamp)) }
                    return .init(timestamp: speed.timestamp, value: self.currentInfo)
                    
                case .minSpeedLost:
                    if speed.value > ahService.minSpeed { return .init(timestamp: speed.timestamp, value: .init(state: .minSpeedReached, stateTimestamp: speed.timestamp)) }
                    return .init(timestamp: speed.timestamp, value: self.currentInfo)

                case .maxSpeedReached:
                    if speed.value < ahService.minSpeed { return .init(timestamp: speed.timestamp, value: .init(state: .minSpeedReached, stateTimestamp: speed.timestamp)) }
                    return .init(timestamp: speed.timestamp, value: self.currentInfo)
                }
            }
            .handleEvents(receiveOutput: { [unowned self] state in
                self.currentInfo = state.value
            })
            .share()
    }()
    
    init(ahService: DeviceMotionProtocol) {
        self.ahService = ahService
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
