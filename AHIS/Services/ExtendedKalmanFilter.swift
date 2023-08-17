//
//  ExtendedKalmanFilter.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 16/08/23.
//

import Foundation
import simd


struct ExtendedKalmanFilter {
    enum Constant {
        static let timeStep: Double = 0.1
    }
    
    var state: simd_double2 = .init(0, 0) // [velocity, acceleration]
    var estimateError: simd_double2x2 = matrix_identity_double2x2
    
    let stateTransition: simd_double2x2 = .init(rows: [.init(1, Constant.timeStep), .init(0, 1)])
    let controlMatrix: simd_double2 = .init(0.5 * Constant.timeStep * Constant.timeStep, Constant.timeStep)
    let observationMatrix: simd_double2x2 = .init(rows: [.init(1, 0.0), .init(0, 0)])
    let processNoise: simd_double2x2 = .init(rows: [.init(0.01, 0), .init(0, 0.1)])
    let measurementNoise: simd_double2x2 = .init(rows: [.init(0.0001, 0), .init(0, 0.001)])
    
    mutating func predictState() {
        state = stateTransition * state
        estimateError = (stateTransition * estimateError * stateTransition.transpose) + processNoise
    }
    
    mutating func updateWithAcceleration(acceleration: Double) {
        /// Acceleration is regarded as a control input to the system, rather than a direct measurement.
        /// As a result, the error associated with the acceleration is incorporated into the process noise during the prediction phase.
        state = state + simd_double2(repeating: acceleration) * controlMatrix
    }
    
    mutating func updateWithVelocity(velocityMeasurement: Double) {
        let residual = velocityMeasurement - (observationMatrix * state)[0]
        let residualCovariance = (observationMatrix * estimateError * observationMatrix.transpose) + measurementNoise
        let invResidualCovariance = residualCovariance.inverse
        let kalmanGain = estimateError * observationMatrix.transpose * invResidualCovariance
        state = state + kalmanGain * .init(residual, 0)
        estimateError = estimateError - (kalmanGain * observationMatrix * estimateError)
    }
}
