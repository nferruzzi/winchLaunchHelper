//
//  ReplayDeviceMotionService.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 17/08/23.
//

import Foundation
import Combine
import CoreGraphics


fileprivate struct Point {
    var x: Double
    var y: Double
}


public final class ReplayDeviceMotionService: DeviceMotionProtocol {
    
    @Published private var deviceMotionQuaternionSubject: DataPointCMQuaternion?
    @Published private var headingSubject: DataPointAngle? = .zero
    @Published private var rollSubject: DataPointAngle? = .zero
    @Published private var pitchSubject: DataPointAngle? = .zero
    @Published private var speedSubject: DataPointSpeed? = .zero
    @Published private var altitudeSubject: DataPointAltitude? = .zero
    @Published private var userAccelerationSubject: DataPointUserAcceleration? = .zero
    
    public var roll: AnyPublisher<DataPointAngle, Never> {
        $rollSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public var pitch: AnyPublisher<DataPointAngle, Never> {
        $pitchSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public var heading: AnyPublisher<DataPointAngle, Never> {
        $headingSubject.compactMap { $0 }.eraseToAnyPublisher()
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
    
    public func reset() {}
    
    private var subscription = Set<AnyCancellable>()
    private var start: Date?
    private var state: SensorState = SensorState(roll: [], pitch: [], heading: [], speed: [], altitude: [], userAcceleration: [])
    private var timestamp: TimeInterval = 0
    
    public init(name: String) {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent(name)
            do {
                let data = try Data(contentsOf: fileURL)
                self.state = try JSONDecoder().decode(SensorState.self, from: data)
                print(self.state.roll.count)
            } catch {
                print(error)
            }
        }
    }
    
    public func reduce(rounded: Int, skip: Bool = false) -> Bool {
        var done = true
        
        if let last = self.state.roll.last, Int(last.timestamp.relativeTimeInterval * 10) <= rounded {
            if !skip { self.rollSubject = last }
            self.state.roll.removeLast()
            done = false
        }

        if let last = self.state.pitch.last, Int(last.timestamp.relativeTimeInterval * 10) <= rounded {
            if !skip { self.pitchSubject = last }
            self.state.pitch.removeLast()
            done = false
        }

        if let last = self.state.speed.last, Int(last.timestamp.relativeTimeInterval * 10) <= rounded {
            if !skip { self.speedSubject = last }
            self.state.speed.removeLast()
            done = false
        }

        if let last = self.state.userAcceleration.last, Int(last.timestamp.relativeTimeInterval * 10) <= rounded {
            if !skip { self.userAccelerationSubject = last }
            self.state.userAcceleration.removeLast()
            done = false
        }

        if let last = self.state.altitude.last, Int(last.timestamp.relativeTimeInterval * 10) <= rounded {
            if !skip { self.altitudeSubject = last }
            self.state.altitude.removeLast()
            done = false
        }

        if let last = self.state.heading.last, Int(last.timestamp.relativeTimeInterval * 10) <= rounded {
            if !skip { self.headingSubject = last }
            self.state.heading.removeLast()
            done = false
        }
        
        return done
    }
    
    public init(bundle: String) {
        do {
            let fileURL = Bundle.main.url(forResource: bundle, withExtension: nil)!
            let data = try Data(contentsOf: fileURL)
            self.state = try JSONDecoder().decode(SensorState.self, from: data)
            print(self.state.roll.count / 10 / 60, " minutes")
        } catch {
            print(error)
        }
        
        let reference = [
            self.state.roll.first?.timestamp,
            self.state.pitch.first?.timestamp,
            self.state.altitude.first?.timestamp,
            self.state.heading.first?.timestamp,
            self.state.userAcceleration.first?.timestamp,
            self.state.speed.first?.timestamp
        ].compactMap { $0 }
        
        if let min = reference.min(by: <=) {
            self.state.roll = self.state.roll.map { $0.toNewRelative(relative: min.relativeTimeInterval) }.reversed()
            self.state.pitch = self.state.pitch.map { $0.toNewRelative(relative: min.relativeTimeInterval) }.reversed()
            self.state.altitude = self.state.altitude.map { $0.toNewRelative(relative: min.relativeTimeInterval) }.reversed()
            self.state.heading = self.state.heading.map { $0.toNewRelative(relative: min.relativeTimeInterval) }.reversed()
            self.state.speed = self.state.speed.map { $0.toNewRelative(relative: min.relativeTimeInterval) }.reversed()
            self.state.userAcceleration = self.state.userAcceleration.map { $0.toNewRelative(relative: min.relativeTimeInterval) }.reversed()
            
            DataPointTimeInterval.relativeOrigin = Date()

            /// skip
            while timestamp <= 40 {
                while self.reduce(rounded: Int(self.timestamp * 10), skip: true) == false {}
                timestamp += 0.1
            }
            
            Timer.publish(every: 0.1, on: RunLoop.main, in: .default)
                .autoconnect()
                .sink { [unowned self] timer in
//                    print(self.timestamp, "sec")
                    while self.reduce(rounded: Int(self.timestamp * 10)) == false {}
                    self.timestamp += 0.1
                }
                .store(in: &subscription)
        }
    }
}
