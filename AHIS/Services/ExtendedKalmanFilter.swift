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
    
    var velocity: Double = 0.0
    var acceleration: Double = 0.0
    
    var estimateError: simd_double2x2 = matrix_identity_double2x2
    
    let stateTransition: simd_double2x2 = .init(rows: [.init(1, Constant.timeStep), .init(0, 1)])
    let observationMatrix: simd_double2x2 = .init(rows: [.init(1, 0), .init(0, 0)]) /// ignore acceleration

    let processNoise: simd_double2x2 = .init(rows: [.init(2, 0.1), .init(0.1, 0.01)])
    let measurementNoise: simd_double2x2 = matrix_identity_double2x2
    
    mutating func predictState() {
        // acceleration remains the same during prediction in this model
//        velocity += acceleration * Constant.timeStep
        estimateError = (stateTransition * estimateError * stateTransition.transpose) + processNoise
    }
    
    mutating func updateWithAcceleration(accelerationValue: Double) {
        acceleration = accelerationValue
        velocity += accelerationValue * Constant.timeStep
    }
    
    mutating func updateWithVelocity(velocityMeasurement: Double) {
        let residual = velocityMeasurement - velocity
        let stateVector = simd_double2(velocity, acceleration)
        let residualCovariance = (observationMatrix * estimateError * observationMatrix.transpose) + measurementNoise
        let invResidualCovariance = residualCovariance.inverse
        let kalmanGain = estimateError * observationMatrix.transpose * invResidualCovariance
        let stateCorrection = kalmanGain * .init(residual, 0)
        let correctedState = stateVector + stateCorrection
        
        velocity = correctedState[0]
        acceleration = correctedState[1]
        estimateError = estimateError - (kalmanGain * observationMatrix * estimateError)
    }
}
