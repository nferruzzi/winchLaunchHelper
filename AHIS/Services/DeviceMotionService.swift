//
//  DeviceMotionService.swift
//  AHIS
//
//  Created by nferruzzi on 08/01/21.
//

import Foundation
import Combine
import CoreMotion
import UIKit
import CoreLocation
import simd


public protocol DeviceMotionProtocol {
    func reset()
    func stop()
    
    var roll: AnyPublisher<DataPointAngle, Never> { get }
    var pitch: AnyPublisher<DataPointAngle, Never> { get }
    var heading: AnyPublisher<DataPointAngle, Never> { get }
    var speed: AnyPublisher<DataPointSpeed, Never> { get }
    var altitude: AnyPublisher<DataPointAltitude, Never> { get }
    var userAcceleration: AnyPublisher<DataPointUserAcceleration, Never> { get }
    var location: AnyPublisher<DataPointLocation, Never> { get }
    var pressure: AnyPublisher<DataPointPressure, Never> { get } 

    var minSpeed: Measurement<UnitSpeed> { get set }
    var maxSpeed: Measurement<UnitSpeed> { get set }
    var winchLength: Measurement<UnitLength> { get set }
    
    var recordState: AnyPublisher<SensorState, Never> { get }
    var record: Bool { get set }
}


extension DeviceMotionProtocol {
    public var minSpeed: Measurement<UnitSpeed> {
        get {
            .init(value: 70, unit: .kilometersPerHour)
        }
        set {
            
        }
    }
    
    public var maxSpeed: Measurement<UnitSpeed> {
        get {
            .init(value: 110, unit: .kilometersPerHour)
        }
        set {
            
        }
    }

    public var winchLength: Measurement<UnitLength> {
        get {
            .init(value: 800, unit: .meters)
        }
        set {
            
        }
    }

    public var record: Bool {
        get { false } set { }
    }
    
    public var recordState: AnyPublisher<SensorState, Never> {
        Just(SensorState()).eraseToAnyPublisher()
    }
}


public struct SensorState: Codable {
    var roll: [DataPointAngle]
    var pitch: [DataPointAngle]
    var heading: [DataPointAngle]
    var speed: [DataPointSpeed]
    var altitude: [DataPointAltitude]
    var userAcceleration: [DataPointUserAcceleration]
    var location: [DataPointLocation]
    var pressure: [DataPointPressure]
    
    init(roll: [DataPointAngle] = [],
         pitch: [DataPointAngle] = [],
         heading: [DataPointAngle] = [],
         speed: [DataPointSpeed] = [],
         altitude: [DataPointAltitude] = [],
         userAcceleration: [DataPointUserAcceleration] = [],
         location: [DataPointLocation] = [],
         pressure: [DataPointPressure] = []) {
        self.roll = roll
        self.pitch = pitch
        self.heading = heading
        self.speed = speed
        self.altitude = altitude
        self.userAcceleration = userAcceleration
        self.location = location
        self.pressure = pressure
    }
    
    func prefix(interval: TimeInterval) -> SensorState {
        .init(roll: roll.filter { $0.timestamp.relativeTimeInterval > interval },
              pitch: pitch.filter { $0.timestamp.relativeTimeInterval > interval },
              heading: heading.filter { $0.timestamp.relativeTimeInterval > interval },
              speed: speed.filter { $0.timestamp.relativeTimeInterval > interval },
              altitude: altitude.filter { $0.timestamp.relativeTimeInterval > interval },
              userAcceleration: userAcceleration.filter { $0.timestamp.relativeTimeInterval > interval },
              location: location.filter { $0.timestamp.relativeTimeInterval > interval },
              pressure: pressure.filter { $0.timestamp.relativeTimeInterval > interval }
        )
    }
    
    func suffix(interval: TimeInterval) -> SensorState {
        .init(roll: roll.filter { $0.timestamp.relativeTimeInterval < interval },
              pitch: pitch.filter { $0.timestamp.relativeTimeInterval < interval },
              heading: heading.filter { $0.timestamp.relativeTimeInterval < interval },
              speed: speed.filter { $0.timestamp.relativeTimeInterval < interval },
              altitude: altitude.filter { $0.timestamp.relativeTimeInterval < interval },
              userAcceleration: userAcceleration.filter { $0.timestamp.relativeTimeInterval < interval },
              location: location.filter { $0.timestamp.relativeTimeInterval < interval },
              pressure: pressure.filter { $0.timestamp.relativeTimeInterval < interval }
        )
    }
    
    func normalize() -> SensorState {
        let reference = [
            roll.first?.timestamp,
            pitch.first?.timestamp,
            heading.first?.timestamp,
            speed.first?.timestamp,
            altitude.first?.timestamp,
            userAcceleration.first?.timestamp,
            location.first?.timestamp,
            pressure.first?.timestamp
        ].compactMap { $0 }
        
        guard let min = reference.min(by: <=) else { return self }
        
        let r = roll.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        let p = pitch.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        let a = altitude.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        let h = heading.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        let s = speed.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        let u = userAcceleration.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        let l = location.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        let b = pressure.map { $0.toNewRelative(relative: min.relativeTimeInterval) }
        
        return .init(roll: r, pitch: p, heading: h, speed: s, altitude: a, userAcceleration: u, location: l, pressure: b)            
    }
}

extension Array {
    mutating func append(_ element: Element?) {
        guard let element = element else { return }
        self.append(element)
    }
}

public final class DeviceMotionService: NSObject {
    
    enum Constants {
        static let manager = CMMotionManager()
        static let locationManager = CLLocationManager()
        static let altimeter = CMAltimeter()
        static let queue = OperationQueue()
        static let userSettingsPitch = "Pitch Zero"
        static let userSettingsRoll = "Roll Zero"
        static let userSettingsMinSpeed = "Min Speed"
        static let userSettingsMaxSpeed = "Max Speed"
        static let userSettingsWinchLength = "Winch Length"
    }

    @Published private var deviceMotionSubject: CMDeviceMotion?
    @Published private var deviceMotionQuaternionSubject: DataPointCMQuaternion?

    @Published private var headingSubject: DataPointAngle? = .zero {
        didSet {
            guard record else { return }
            serialization.heading.append(headingSubject?.toRelative())
        }
    }
    
    @Published private var rollSubject: DataPointAngle? = .zero {
        didSet {
            guard record else { return }
            serialization.roll.append(rollSubject?.toRelative())
        }
    }
    
    @Published private var pitchSubject: DataPointAngle? = .zero {
        didSet {
            guard record else { return }
            serialization.pitch.append(pitchSubject?.toRelative())
        }
    }
    
    @Published private var speedSubject: DataPointSpeed? = .zero {
        didSet {
            guard record else { return }
            serialization.speed.append(speedSubject?.toRelative())
        }
    }
    
    @Published private var altitudeSubject: DataPointAltitude? = .zero {
        didSet {
            guard record else { return }
            serialization.altitude.append(altitudeSubject?.toRelative())
        }
    }
    
    @Published private var userAccelerationSubject: DataPointUserAcceleration? = .zero {
        didSet {
            guard record else { return }
            serialization.userAcceleration.append(userAccelerationSubject?.toRelative())
        }
    }
    
    @Published private var locationSubject: DataPointLocation? = .zero {
        didSet {
            guard record else { return }
            serialization.location.append(locationSubject?.toRelative())
        }
    }
    
    @Published private var pressureSubject: DataPointPressure? = .zero {
        didSet {
            guard record else { return }
            serialization.pressure.append(pressureSubject?.toRelative())
        }
    }

    public var minSpeed: Measurement<UnitSpeed> = .init(value: 70, unit: .kilometersPerHour) {
        didSet {
            UserDefaults.standard.set(minSpeed.converted(to: .kilometersPerHour).value, forKey: Constants.userSettingsMinSpeed)
            UserDefaults.standard.synchronize()
        }
    }
    
    public var maxSpeed: Measurement<UnitSpeed> = .init(value: 110, unit: .kilometersPerHour) {
        didSet {
            UserDefaults.standard.set(maxSpeed.converted(to: .kilometersPerHour).value, forKey: Constants.userSettingsMaxSpeed)
            UserDefaults.standard.synchronize()
        }
    }

    public var winchLength: Measurement<UnitLength> = .init(value: 800, unit: .meters) {
        didSet {
            UserDefaults.standard.set(winchLength.converted(to: .meters).value, forKey: Constants.userSettingsWinchLength)
            UserDefaults.standard.synchronize()
        }
    }

    public var record: Bool = false {
        didSet {
            serialization = SensorState()
        }
    }
    
    private var subscriptions = Set<AnyCancellable>()
    private var latestAttitude: CMAttitude?
    private var rotate: Double = 10
    private var prevHeading: Double = 0

    private var pitchZero: Double?
    private var rollZero: Double?
    
    @Published private var serialization: SensorState = SensorState()
    
    public override init() {
        super.init()
        Constants.manager.showsDeviceMovementDisplay = true
        Constants.manager.deviceMotionUpdateInterval = TimeInterval(1.0/10.0)

        Constants.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        Constants.locationManager.activityType = .airborne
        Constants.locationManager.pausesLocationUpdatesAutomatically = false
        Constants.locationManager.delegate = self
        
        pitchZero = UserDefaults.standard.double(forKey: Constants.userSettingsPitch)
        rollZero = UserDefaults.standard.double(forKey: Constants.userSettingsRoll)
        
        let minSpeedValue = UserDefaults.standard.double(forKey: Constants.userSettingsMinSpeed)
        let maxSpeedValue = UserDefaults.standard.double(forKey: Constants.userSettingsMaxSpeed)
        let winchLengthValue = UserDefaults.standard.double(forKey: Constants.userSettingsWinchLength)
        
        minSpeed = .init(value: minSpeedValue > 0 ? minSpeedValue : 70, unit: .kilometersPerHour)
        maxSpeed = .init(value: maxSpeedValue > 0 ? maxSpeedValue : 110, unit: .kilometersPerHour)
        winchLength = .init(value: maxSpeedValue > 0 ? winchLengthValue : 800, unit: .meters)

        start(reference: .xMagneticNorthZVertical)
        
        if Constants.locationManager.authorizationStatus == .notDetermined {
            Constants.locationManager.requestWhenInUseAuthorization()
        }
        
        $deviceMotionQuaternionSubject
            .sink { [unowned self] attitude in
                guard let attitude = attitude else { return }
                let pitch = attitude.value.simdQuatd.pitch - (self.pitchZero ?? 0)
                let roll = attitude.value.simdQuatd.roll - (self.rollZero ?? 0)
                self.pitchSubject = .init(timestamp: attitude.timestamp, value: .init(value: pitch, unit: .radians))
                self.rollSubject = .init(timestamp: attitude.timestamp, value: .init(value: roll, unit: .radians))
            }
            .store(in: &subscriptions)
    }
    
    static func replayList() -> [URL] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        let files = (try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        let apollonia = [Bundle.main.url(forResource: "k2_apollonia_strong_wind_1", withExtension: "json")!]
        
        return apollonia + files.filter { url in
            url.pathExtension == "json"
        }
    }
    
    private func start(reference: CMAttitudeReferenceFrame) {
        Constants.manager.stopDeviceMotionUpdates()
        Constants.manager.startDeviceMotionUpdates(using: reference, to: Constants.queue) { [weak self](motion: CMDeviceMotion?, error: Error?) in
            guard let motion = motion else { return }
            guard let self = self else { return }
            
            let heading = motion.heading
            
            if heading > 270 && self.prevHeading <= 90 {
                self.rotate -= 1
//                debugPrint("bug da 0 a 360 \(motion.heading) \(self.rotate)")
            }
            else
            if motion.heading < 90 && self.prevHeading > 270 {
                self.rotate += 1
//                debugPrint("bug da 360 a 0 \(motion.heading) \(self.rotate)")
            }
            
            self.userAccelerationSubject = .init(timestamp: .date(motion.date),
                                                 value: motion.userAcceleration)

            self.prevHeading = motion.heading
            self.headingSubject = .init(timestamp: .date(motion.date),
                                        value: .init(value: heading + self.rotate * 360, unit: .degrees))
            self.latestAttitude = motion.attitude.copy() as? CMAttitude

            self.deviceMotionQuaternionSubject = .init(timestamp: .date(motion.date),
                                                       value: motion.attitude.quaternion)
        }
        
        Constants.altimeter.startRelativeAltitudeUpdates(to: Constants.queue) { [weak self] altitude, error in
            guard error == nil else { return }
            guard let altitude = altitude else { return }
            let kp = altitude.pressure.doubleValue
            self?.pressureSubject = .init(timestamp: .date(altitude.date),
                                          value: .init(value: kp, unit: .kilopascals))
        }
    }
}


extension DeviceMotionService: DeviceMotionProtocol {
    public var heading: AnyPublisher<DataPointAngle, Never> {
        $headingSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    public var roll: AnyPublisher<DataPointAngle, Never> {
        $rollSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    public var pitch: AnyPublisher<DataPointAngle, Never> {
        $pitchSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    public var speed: AnyPublisher<DataPointSpeed, Never> {
        $speedSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public var altitude: AnyPublisher<DataPointAltitude, Never> {
        $altitudeSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public var userAcceleration: AnyPublisher<DataPointUserAcceleration, Never> {
        $userAccelerationSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public var location: AnyPublisher<DataPointLocation, Never> {
        $locationSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public var pressure: AnyPublisher<DataPointPressure, Never> {
        $pressureSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public func reset() {
        defer {
            UserDefaults.standard.set(pitchZero, forKey: Constants.userSettingsPitch)
            UserDefaults.standard.set(rollZero, forKey: Constants.userSettingsRoll)
            UserDefaults.standard.synchronize()
        }
        
        guard let latestAttitude = latestAttitude else {
            pitchZero = nil
            rollZero = nil
            return
        }
        
        pitchZero = latestAttitude.quaternion.simdQuatd.pitch
        rollZero = latestAttitude.quaternion.simdQuatd.roll
    }
    
    public func stop() {
        subscriptions.removeAll()
    }
    
    public var recordState: AnyPublisher<SensorState, Never> {
        $serialization.eraseToAnyPublisher()
    }
}


extension DeviceMotionService: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .denied && manager.authorizationStatus != .notDetermined else { return }
        print("auth", manager.authorizationStatus.rawValue)
        
        if manager.accuracyAuthorization == .reducedAccuracy {
            Task { @MainActor in
                do {
                    try await Constants.locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "AccurateSpeed")
                } catch {
                    print("full accuracy", error)
                }
                manager.startUpdatingLocation()

            }
        } else {
            manager.startUpdatingLocation()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last(where: { $0.speedAccuracy > 0 }) else { return }
        speedSubject = .init(timestamp: .date(last.timestamp),
                             value: .init(value: last.speed, unit: .metersPerSecond))
        altitudeSubject = .init(timestamp: .date(last.timestamp),
                                value: .init(value: last.altitude, unit: .meters))
        locationSubject = .init(timestamp: .date(last.timestamp),
                                value: last.coordinate)
    }
    
    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("fail", manager.authorizationStatus.rawValue, error)
    }
}

