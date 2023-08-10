//
//  DataPoint.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import Foundation
import CoreMotion


public struct DataPoint<Value: Equatable>: Equatable {
    typealias ValueType = Value
    
    public let date:  Date
    public let value: Value
}

extension DataPoint where Value == Measurement<UnitSpeed> {
    static var zero: Self {
        .init(date: Date.distantPast, value: .init(value: 0, unit: .metersPerSecond))
    }
}

extension DataPoint where Value == Measurement<UnitAcceleration> {
    static var zero: Self {
        .init(date: Date.distantPast, value: .init(value: 0, unit: .metersPerSecondSquared))
    }
}

extension DataPoint where Value == Measurement<UnitLength> {
    static var zero: Self {
        .init(date: Date.distantPast, value: .init(value: 0, unit: .meters))
    }
}

extension DataPoint where Value == Measurement<UnitAngle> {
    static var zero: Self {
        .init(date: Date.distantPast, value: .init(value: 0, unit: .radians))
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
