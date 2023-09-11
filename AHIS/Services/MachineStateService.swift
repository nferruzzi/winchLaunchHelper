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
    
    case completed
    case aborted
}

struct MachineInfo: Equatable, Codable {
    let state: MachineState
    let stateTimestamp: DataPointTimeInterval

    let takeOffAltitude: DataPointAltitude?
    let maxAltitude: DataPointAltitude?
    let finalAltitude: DataPointAltitude?
    
    var isLaunching: Bool {
        state != .waiting && state != .aborted && state != .completed
    }
    
    init(state: MachineState,
         stateTimestamp: DataPointTimeInterval,
         takeOffAltitude: DataPointAltitude? = nil,
         maxAltitude: DataPointAltitude? = nil,
         finalAltitude: DataPointAltitude? = nil
    ) {
        self.state = state
        self.stateTimestamp = stateTimestamp
        self.takeOffAltitude = takeOffAltitude
        self.maxAltitude = maxAltitude
        self.finalAltitude = finalAltitude
    }

    func with(state: MachineState? = nil,
              stateTimestamp: DataPointTimeInterval? = nil,
              takeOffAltitude: DataPointAltitude? = nil,
              maxAltitude: DataPointAltitude? = nil,
              finalAltitude: DataPointAltitude? = nil
    ) -> MachineInfo {
        MachineInfo(state: state ?? self.state,
                    stateTimestamp: stateTimestamp ?? self.stateTimestamp,
                    takeOffAltitude: takeOffAltitude ?? self.takeOffAltitude,
                    maxAltitude: maxAltitude ?? self.maxAltitude,
                    finalAltitude: finalAltitude ?? self.finalAltitude
        )
    }
}


typealias DataPointMachineState = DataPoint<MachineInfo>

protocol MachineStateProtocol {
    var speed: AnyPublisher<DataPointSpeed, Never> { get }
    var altitude: AnyPublisher<DataPointAltitude, Never> { get }
    var acceleration: AnyPublisher<DataPointAcceleration, Never> { get }
    var machineState: AnyPublisher<DataPointMachineState, Never> { get }
    
    func reset()
}


final class MachineStateService {
    enum Constants {
        static let windowSize: Int = 10
        static let accelerationThreshold = Measurement<UnitAcceleration>(value: 1.0, unit: .metersPerSecondSquared)
        static let speedThreshold = Measurement<UnitSpeed>(value: 10, unit: .kilometersPerHour)
        static let abortThreshold = Measurement<UnitLength>(value: 1, unit: .meters)
        
        // CoreLocation generates just 1 msg per second, we interpolate the speed to have more
        static let throttleSeconds: Double = 0.01
    }
    
    
    private var ahService: DeviceMotionProtocol
    private var lastPublishedTime: Date?
    private var speeds: [DataPointSpeed] = []
    private var notStoppedTime: Date?
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
    
    lazy var smoothedAltitudePublisher: some Publisher<DataPointAltitude, Never> = {
        ahService.pressure.map { value in
            func altitudeFromPressure(pressureInKPa: Double) -> Double {
                let P0 = 101.325
                let altitude = 44330 * (1 - pow((pressureInKPa / P0), (1/5.257)))
                return altitude
            }
            let mt = altitudeFromPressure(pressureInKPa: value.value.converted(to: .kilopascals).value)
            return .init(timestamp: value.timestamp, value: .init(value: mt, unit: .meters))
        }
    }()

    lazy var accelerationPublisher: some Publisher<DataPointAcceleration, Never> = {
        ahService.userAcceleration.map { dataPoint in
            let measure = Measurement<UnitAcceleration>(value: dataPoint.value.z, unit: .gravity)
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
        Publishers.CombineLatest3(
            smoothedSpeedPublisher,
            smoothedAccelerationsPublisher,
            smoothedAltitudePublisher
        )
            .map { [unowned self] speed, acceleration, altitude in
                let currentMaxAltitude = self.currentInfo.maxAltitude ?? .zero
                let maxAltitude: DataPointAltitude = currentMaxAltitude.value > altitude.value ? currentMaxAltitude : altitude

                var def = DataPointMachineState(timestamp: speed.timestamp,
                                                value: self.currentInfo.with(maxAltitude: maxAltitude))

                
                if self.currentInfo.isLaunching, let tof = self.currentInfo.takeOffAltitude {
                    let altitudeDiff = (altitude.value - tof.value)
                    let abortedTime = tof.timestamp.relativeTimeInterval + 5
                    let completedTime = tof.timestamp.relativeTimeInterval + 40
                    
                    if speed.value < Constants.speedThreshold && altitudeDiff < Constants.abortThreshold && speed.timestamp.relativeTimeInterval > abortedTime {
                        def.value = def.value.with(state: .aborted, stateTimestamp: speed.timestamp, finalAltitude: altitude)
                        return def
                    }
                    
                    
                    if speed.timestamp.relativeTimeInterval > completedTime {
                        def.value = def.value.with(state: .completed, stateTimestamp: speed.timestamp, finalAltitude: altitude)
                        return def
                    }
                }
                
//                print("\(naturalScale: speed.value) \(naturalScale: ahService.minSpeed) \(naturalScale: ahService.maxSpeed)")
                
                switch self.currentInfo.state {
                case .waiting:
                    if speed.value > Constants.speedThreshold {
                        def.value = def.value.with(state: .takingOff, stateTimestamp: speed.timestamp, takeOffAltitude: altitude)
                    }
                    
                    return def

                case .takingOff:
                    if speed.value > ahService.maxSpeed {
                        def.value = def.value.with(state: .maxSpeedReached, stateTimestamp: speed.timestamp)
                    } else {
                        if speed.value > ahService.minSpeed {
                            def.value = def.value.with(state: .minSpeedReached, stateTimestamp: speed.timestamp)
                        }
                    }
                    
                    return def

                case .minSpeedReached:
                    if speed.value < ahService.minSpeed {
                        def.value = def.value.with(state: .minSpeedLost, stateTimestamp: speed.timestamp)
                    }
                    
                    if speed.value > ahService.maxSpeed {
                        def.value = def.value.with(state: .maxSpeedReached, stateTimestamp: speed.timestamp)
                    }
                    
                    return def

                case .minSpeedLost:
                    if speed.value > ahService.maxSpeed {
                        def.value = def.value.with(state: .maxSpeedReached, stateTimestamp: speed.timestamp)
                    } else {
                        if speed.value > ahService.minSpeed {
                            def.value = def.value.with(state: .minSpeedReached, stateTimestamp: speed.timestamp)
                        }
                    }
                    
                    return def

                case .maxSpeedReached:
                    if speed.value < ahService.minSpeed {
                        def.value = def.value.with(state: .minSpeedReached, stateTimestamp: speed.timestamp)
                    }
                    
                    return def

                case .aborted, .completed:
                    return DataPointMachineState(timestamp: speed.timestamp, value: self.currentInfo)
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
    
    func reset() {
        self.currentInfo = .init(state: .waiting, stateTimestamp: .date(Date()))
        self.accelerations.removeAll()
        self.speeds.removeAll()
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
    
    var altitude: AnyPublisher<DataPointAltitude, Never> {
        smoothedAltitudePublisher.eraseToAnyPublisher()
    }
}
