//
//  DataPoint.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import Foundation
import CoreMotion
import simd


public enum DataPointTimeInterval: Equatable, Codable {
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


public struct DataPoint<Value: Equatable & Codable>: Equatable, Codable {
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
    
    public func toRelative() -> Self {
        return .init(timestamp: .relative(timestamp.relativeTimeInterval), value: value)
    }
    
    public func toScaledRelative(relative: TimeInterval) -> Self {
        return .init(timestamp: .relative(Double(Int(timestamp.relativeTimeInterval - relative) * 10)), value: value)
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

extension CMAcceleration: Codable {
    
    enum CodingKeys: String, CodingKey {
        case x
        case y
        case z
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let z = try container.decode(Double.self, forKey: .z)
        self.init(x: x, y: y, z: z)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
    }
}

extension CMQuaternion: Codable {
    
    enum CodingKeys: String, CodingKey {
        case x
        case y
        case z
        case w
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let z = try container.decode(Double.self, forKey: .z)
        let w = try container.decode(Double.self, forKey: .w)
        self.init(x: x, y: y, z: z, w: w)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
        try container.encode(w, forKey: .w)
    }
}


extension DataPoint where Value == CMAcceleration {
    static var zero: Self {
        .init(timestamp: .relative(0), value: .init())
    }
}

extension CMQuaternion: Equatable {
    public static func == (lhs: CMQuaternion, rhs: CMQuaternion) -> Bool {
        lhs.simdQuatd == rhs.simdQuatd
    }
}

extension CMAcceleration: Equatable {
    public static func == (lhs: CMAcceleration, rhs: CMAcceleration) -> Bool {
        lhs.simDouble3 == rhs.simDouble3
    }
}

public typealias DataPointSpeed = DataPoint<Measurement<UnitSpeed>>
public typealias DataPointAngle = DataPoint<Measurement<UnitAngle>>
public typealias DataPointAltitude = DataPoint<Measurement<UnitLength>>
public typealias DataPointAcceleration = DataPoint<Measurement<UnitAcceleration>>
public typealias DataPointCMQuaternion = DataPoint<CMQuaternion>
public typealias DataPointPressure = DataPoint<Measurement<UnitPressure>>
public typealias DataPointUserAcceleration = DataPoint<CMAcceleration>
