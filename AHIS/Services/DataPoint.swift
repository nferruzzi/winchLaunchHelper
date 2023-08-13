//
//  DataPoint.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import Foundation
import CoreMotion

public enum DataPointTimeInterval: Equatable {
    static var relativeOrigin = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)

    case date(Date)
    case relative(TimeInterval)
    
    var relativeTimeInterval: TimeInterval {
        switch self {
        case let .date(value):
            return value.timeIntervalSince(DataPointTimeInterval.relativeOrigin)
        case let .relative(value):
            return value
        }
    }
    
    public static func == (lhs: DataPointTimeInterval, rhs: DataPointTimeInterval) -> Bool {
        lhs.relativeTimeInterval == rhs.relativeTimeInterval
    }
    
    public static func <= (lhs: DataPointTimeInterval, rhs: DataPointTimeInterval) -> Bool {
        lhs.relativeTimeInterval <= rhs.relativeTimeInterval
    }
}


extension Date {
    public var timeRelativeToDataPointInterval: TimeInterval {
        DataPointTimeInterval.date(self).relativeTimeInterval
    }
}


public struct DataPoint<Value: Equatable>: Equatable {
    typealias ValueType = Value
    
    public let value: Value
    public var timestamp: DataPointTimeInterval
    
    public init(timestamp: DataPointTimeInterval, value: Value) {
        self.timestamp = timestamp
        self.value = value
    }
    
    public init(date: Date, value: Value) {
        self.timestamp = .date(date)
        self.value = value
    }
}


extension DataPoint where Value == Measurement<UnitSpeed> {
    static var zero: Self {
        .init(timestamp: .relative(0), value: .init(value: 0, unit: .metersPerSecond))
    }
}

extension DataPoint where Value == Measurement<UnitAcceleration> {
    static var zero: Self {
        .init(timestamp: .relative(0), value: .init(value: 0, unit: .metersPerSecondSquared))
    }
}

extension DataPoint where Value == Measurement<UnitLength> {
    static var zero: Self {
        .init(timestamp: .relative(0), value: .init(value: 0, unit: .meters))
    }
}

extension DataPoint where Value == Measurement<UnitAngle> {
    static var zero: Self {
        .init(timestamp: .relative(0), value: .init(value: 0, unit: .radians))
    }
}

extension DataPoint where Value == Measurement<UnitPressure> {
    static var zero: Self {
        .init(timestamp: .relative(0), value: .init(value: 0, unit: .hectopascals))
    }
}

extension CMQuaternion: Equatable {
    public static func == (lhs: CMQuaternion, rhs: CMQuaternion) -> Bool {
        lhs.simdQuatd == rhs.simdQuatd
    }
}

public typealias DataPointSpeed = DataPoint<Measurement<UnitSpeed>>
public typealias DataPointAngle = DataPoint<Measurement<UnitAngle>>
public typealias DataPointAltitude = DataPoint<Measurement<UnitLength>>
public typealias DataPointAcceleration = DataPoint<Measurement<UnitAcceleration>>
public typealias DataPointCMQuaternion = DataPoint<CMQuaternion>
public typealias DataPointPressure = DataPoint<Measurement<UnitPressure>>
