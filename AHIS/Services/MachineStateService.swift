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
    case landed
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
        /// Hysteresis margin for speed transitions to avoid chatty callouts
        static let speedHysteresis = Measurement<UnitSpeed>(value: 5, unit: .kilometersPerHour)

        // how long to wait before going back to landed/waiting
        static let landedSeconds: TimeInterval = 60

        // CoreLocation generates just 1 msg per second, we interpolate the speed to have more
        static let throttleSeconds: Double = 0.01
    }
    
    
    private var ahService: DeviceMotionProtocol
    private var lastPublishedTime: Date?
    private var speeds: [DataPointSpeed] = []
    private var notStoppedTime: Date?
    /// KF for speed: state = [flightPathSpeed, acceleration], fuses GPS (1Hz) + accelerometer (50Hz)
    private var speedKF = KalmanFilter(timeStep: 0.02, processNoiseIntensity: 5.0, measurementNoiseVariance: 1.0)
    /// KF for altitude: state = [altitude, verticalSpeed], fuses barometer (~1Hz) + vertical accel (50Hz)
    private var altitudeKF = KalmanFilter(timeStep: 0.02, processNoiseIntensity: 2.0, measurementNoiseVariance: 0.5)
    private var accelerations: [DataPointAcceleration] = []
    /// Latest pitch angle in radians, used to project acceleration along flight path
    private var latestPitch: Double = 0.0

    private var currentInfo: MachineInfo = .init(state: .waiting, stateTimestamp: .date(Date()))
    private var pitchSubscription: AnyCancellable?

    lazy var interpolatedSpeedPublisher: some Publisher<DataPointSpeed, Never> = {
        ahService.speed
        .map { [unowned self] dataPoint in
            // Correct GPS ground speed to approximate flight path speed:
            // groundSpeed = flightPathSpeed * cos(pitch), so flightPathSpeed = groundSpeed / cos(pitch)
            let pitch = self.latestPitch
            let cosPitch = cos(pitch)
            let correctedSpeed: Double
            if abs(cosPitch) > 0.3 { // avoid division by near-zero at extreme pitch (>~72°)
                correctedSpeed = dataPoint.value.value / cosPitch
            } else {
                correctedSpeed = dataPoint.value.value / 0.3
            }
            // At low GPS speed (< 3 m/s ≈ 11 km/h), use very low measurement noise so
            // GPS strongly anchors the filter to near-zero — prevents accelerometer drift
            // from accumulating while stationary. At flight speed, use default R.
            let lowSpeedThreshold = 3.0 // m/s
            let R: Double = dataPoint.value.value < lowSpeedThreshold ? 0.01 : self.speedKF.measurementNoiseVariance
            self.speedKF.update(measurement: correctedSpeed, noiseVariance: R)
            return self.accelerationPublisher
        }
        .switchToLatest()
        .map { [unowned self] dataPoint in
            self.speedKF.predict(controlInput: dataPoint.value.value)

            // Clamp to non-negative: negative flight path speed is physically meaningless
            let speed = max(0, self.speedKF.position)
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
    
    /// Vertical acceleration publisher (Z axis in reference frame, converted to m/s²)
    lazy var verticalAccelerationPublisher: some Publisher<DataPointAcceleration, Never> = {
        ahService.userAcceleration.map { dataPoint in
            let measure = Measurement<UnitAcceleration>(value: dataPoint.value.z, unit: .gravity)
            return .init(timestamp: dataPoint.timestamp, value: measure.converted(to: .metersPerSecondSquared))
        }
        .share()
    }()

    /// Altitude interpolated at 10Hz: barometer (~1Hz) fused with vertical acceleration (10Hz) via KF
    lazy var smoothedAltitudePublisher: some Publisher<DataPointAltitude, Never> = {
        ahService.pressure
        .map { [unowned self] value in
            func altitudeFromPressure(pressureInKPa: Double) -> Double {
                let P0 = 101.325
                return 44330 * (1 - pow((pressureInKPa / P0), (1/5.257)))
            }
            let mt = altitudeFromPressure(pressureInKPa: value.value.converted(to: .kilopascals).value)
            self.altitudeKF.update(measurement: mt)
            return self.verticalAccelerationPublisher
        }
        .switchToLatest()
        .map { [unowned self] dataPoint in
            self.altitudeKF.predict(controlInput: dataPoint.value.value)
            let alt = self.altitudeKF.position
            return DataPointAltitude(timestamp: dataPoint.timestamp, value: .init(value: alt, unit: .meters))
        }
        .share()
    }()

    lazy var accelerationPublisher: some Publisher<DataPointAcceleration, Never> = {
        ahService.userAcceleration.map { [unowned self] dataPoint in
            // userAcceleration is in xMagneticNorthZVertical reference frame (gravity removed):
            // X = north, Y = east, Z = up
            // Project onto flight path direction using pitch angle:
            // a_flightPath = a_horizontal * cos(pitch) + a_vertical * sin(pitch)
            // where a_horizontal = sqrt(ax² + ay²) with sign from forward direction
            let pitch = self.latestPitch
            let ax = dataPoint.value.x // north component (g)
            let ay = dataPoint.value.y // east component (g)
            let az = dataPoint.value.z // vertical component (g)
            // Use signed horizontal acceleration: positive = forward along heading.
            // sqrt() would always be positive, creating a systematic bias that accumulates
            // in the Kalman filter even when stationary. Using the dominant axis with sign
            // preserves directionality so noise cancels out over time.
            let aHorizontal = (abs(ax) > abs(ay)) ? ax : ay
            let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
            let measure = Measurement<UnitAcceleration>(value: aFlightPath, unit: .gravity)
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
            let newInfo = MachineStateService.transition(
                currentInfo: self.currentInfo,
                speed: speed,
                altitude: altitude,
                minSpeed: self.ahService.minSpeed,
                maxSpeed: self.ahService.maxSpeed
            )
            return DataPointMachineState(timestamp: speed.timestamp, value: newInfo)
        }
        .handleEvents(receiveOutput: { [unowned self] state in
            self.currentInfo = state.value
        })
        .share()
    }()
    
    /// Pure function for state transitions — extracted for testability
    static func transition(
        currentInfo: MachineInfo,
        speed: DataPointSpeed,
        altitude: DataPointAltitude,
        minSpeed: Measurement<UnitSpeed>,
        maxSpeed: Measurement<UnitSpeed>
    ) -> MachineInfo {
        let currentMaxAltitude = currentInfo.maxAltitude ?? .zero
        let maxAltitude: DataPointAltitude = currentMaxAltitude.value > altitude.value ? currentMaxAltitude : altitude
        var info = currentInfo.with(maxAltitude: maxAltitude)

        if currentInfo.isLaunching, let tof = currentInfo.takeOffAltitude {
            let altitudeDiff = (altitude.value - tof.value)
            let abortedTime = tof.timestamp.relativeTimeInterval + 10
            let completedTime = tof.timestamp.relativeTimeInterval + 40

            if speed.value < Constants.speedThreshold && altitudeDiff < Constants.abortThreshold && speed.timestamp.relativeTimeInterval > abortedTime {
                return info.with(state: .aborted, stateTimestamp: speed.timestamp, finalAltitude: altitude)
            }

            if speed.timestamp.relativeTimeInterval > completedTime {
                return info.with(state: .completed, stateTimestamp: speed.timestamp, finalAltitude: altitude)
            }
        }

        let hysteresis = Constants.speedHysteresis

        switch currentInfo.state {
        case .waiting:
            if speed.value > Constants.speedThreshold {
                info = info.with(state: .takingOff, stateTimestamp: speed.timestamp, takeOffAltitude: altitude)
            }
            return info

        case .takingOff:
            if speed.value > minSpeed {
                info = info.with(state: .minSpeedReached, stateTimestamp: speed.timestamp)
            }
            return info

        case .minSpeedReached:
            if speed.value > maxSpeed {
                info = info.with(state: .maxSpeedReached, stateTimestamp: speed.timestamp)
            } else if speed.value < minSpeed - hysteresis {
                info = info.with(state: .minSpeedLost, stateTimestamp: speed.timestamp)
            }
            return info

        case .minSpeedLost:
            if speed.value > maxSpeed {
                info = info.with(state: .maxSpeedReached, stateTimestamp: speed.timestamp)
            } else if speed.value > minSpeed + hysteresis {
                info = info.with(state: .minSpeedReached, stateTimestamp: speed.timestamp)
            }
            return info

        case .maxSpeedReached:
            if speed.value < minSpeed - hysteresis {
                info = info.with(state: .minSpeedLost, stateTimestamp: speed.timestamp)
            } else if speed.value < maxSpeed - hysteresis {
                info = info.with(state: .minSpeedReached, stateTimestamp: speed.timestamp)
            }
            return info

        case .aborted, .completed:
            if let tof = currentInfo.takeOffAltitude,
               speed.timestamp.relativeTimeInterval > currentInfo.stateTimestamp.relativeTimeInterval + Constants.landedSeconds && fabs(altitude.value.value - tof.value.value) < 10 {
                return .init(state: .waiting, stateTimestamp: speed.timestamp)
            }
            return currentInfo

        case .landed:
            return .init(state: .waiting, stateTimestamp: speed.timestamp)
        }
    }

    init(ahService: DeviceMotionProtocol) {
        self.ahService = ahService
        // Anchor KFs at zero with tight noise so accelerometer noise
        // doesn't build up speed/altitude before first GPS/baro reading
        self.speedKF.update(measurement: 0.0, noiseVariance: 0.001)
        self.altitudeKF.update(measurement: 0.0, noiseVariance: 0.001)
        self.pitchSubscription = ahService.pitch
            .sink { [weak self] dataPoint in
                self?.latestPitch = dataPoint.value.value
            }
    }
        
    private func calculateMovingAverage() -> CLLocationSpeed {
        speeds.reduce(0, { $0 + $1.value.value }) / CLLocationSpeed(speeds.count)
    }
    
    func reset() {
        self.currentInfo = .init(state: .waiting, stateTimestamp: .date(Date()))
        self.accelerations.removeAll()
        self.speeds.removeAll()
        self.speedKF = KalmanFilter(timeStep: 0.02, processNoiseIntensity: 5.0, measurementNoiseVariance: 1.0)
        self.altitudeKF = KalmanFilter(timeStep: 0.02, processNoiseIntensity: 2.0, measurementNoiseVariance: 0.5)
        // Anchor both KFs at zero with very tight noise so accelerometer noise
        // doesn't immediately rebuild speed/altitude before the next GPS/baro update
        self.speedKF.update(measurement: 0.0, noiseVariance: 0.001)
        self.altitudeKF.update(measurement: 0.0, noiseVariance: 0.001)
        self.latestPitch = 0.0
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
