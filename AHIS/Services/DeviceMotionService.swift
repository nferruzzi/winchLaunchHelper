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

public struct DataPoint<Value: Equatable>: Equatable {
    public let date:  Date
    public let value: Value
}

public typealias DataPointSpeed = DataPoint<Measurement<UnitSpeed>>

public protocol DeviceMotionProtocol {
    func reset()
    
    var roll: AnyPublisher<Double, Never> { get }
    var pitch: AnyPublisher<Double, Never> { get }
    var heading: AnyPublisher<Double, Never> { get }
    var speed: AnyPublisher<DataPointSpeed, Never> { get }
}


public final class DeviceMotionService: NSObject {
    
    enum Constants {
        static let manager = CMMotionManager()
        static let locationManager = CLLocationManager()
        static let queue = OperationQueue()
        static let userSettingsPitch = "Pitch Zero"
        static let userSettingsRoll = "Roll Zero"
    }

    @Published private var deviceMotionSubject: CMDeviceMotion?
    @Published private var deviceMotionQuaternionSubject: CMQuaternion?
    @Published private var headingSubject: Double = 0
    @Published private var rollSubject: Double = 0
    @Published private var pitchSubject: Double = 0
    @Published private var speedSubject: DataPointSpeed = .init(date: Date.distantPast, value: .init(value: 0, unit: .kilometersPerHour))
    @Published private var altitudeSubject: (Date, Double) = (Date.distantPast, 0)

    private var subscriptions = Set<AnyCancellable>()
    private var latestAttitude: CMAttitude?
    private var rotate: Double = 10
    private var prevHeading: Double = 0

    private var pitchZero: Double?
    private var rollZero: Double?
    
    public override init() {
        super.init()
        Constants.manager.showsDeviceMovementDisplay = true
        Constants.manager.deviceMotionUpdateInterval = TimeInterval(1.0/100.0)

        Constants.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        Constants.locationManager.activityType = .airborne
        Constants.locationManager.pausesLocationUpdatesAutomatically = false
        Constants.locationManager.delegate = self
        
        pitchZero = UserDefaults.standard.double(forKey: Constants.userSettingsPitch)
        rollZero = UserDefaults.standard.double(forKey: Constants.userSettingsRoll)
        
        start(reference: .xMagneticNorthZVertical)
        
        if Constants.locationManager.authorizationStatus == .notDetermined {
            Constants.locationManager.requestWhenInUseAuthorization()
        }
        
        $deviceMotionQuaternionSubject
            .sink { [unowned self] attitude in
                guard let attitude = attitude else { return }
                self.pitchSubject = attitude.simdQuatd.pitch - (self.pitchZero ?? 0)
                self.rollSubject = attitude.simdQuatd.roll - (self.rollZero ?? 0)
            }
            .store(in: &subscriptions)
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

            self.prevHeading = motion.heading
            self.headingSubject = heading + self.rotate * 360
            self.latestAttitude = motion.attitude.copy() as? CMAttitude
            self.deviceMotionQuaternionSubject = motion.attitude.quaternion
        }
    }
}


extension DeviceMotionService: DeviceMotionProtocol {
    public var heading: AnyPublisher<Double, Never> {
        $headingSubject.removeDuplicates().eraseToAnyPublisher()
    }

    public var roll: AnyPublisher<Double, Never> {
        $rollSubject.removeDuplicates().eraseToAnyPublisher()
    }

    public var pitch: AnyPublisher<Double, Never> {
        $pitchSubject.removeDuplicates().eraseToAnyPublisher()
    }

    public var speed: AnyPublisher<DataPointSpeed, Never> {
        $speedSubject.removeDuplicates().eraseToAnyPublisher()
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
        speedSubject = .init(date: last.timestamp, value: .init(value: last.speed, unit: .metersPerSecond))
        altitudeSubject = (last.timestamp, last.altitude)
    }
    
    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("fail", manager.authorizationStatus.rawValue, error)
    }
}

