//
//  KalmanFilter.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 16/08/23.
//
//  Generic linear Kalman Filter with state [position, velocity].
//  Used for both speed estimation (GPS+accelerometer) and altitude estimation (barometer+accelerometer).
//
//  Reference material for future improvements
//  https://www.youtube.com/watch?v=HkYRJJoyBwQ
//  https://ardupilot.org/dev/docs/extended-kalman-filter.html


import Foundation
import simd


struct KalmanFilter {
    let timeStep: Double
    let processNoise: simd_double2x2
    let measurementNoiseVariance: Double

    /// State vector: [position, velocity] (or [velocity, acceleration] depending on usage)
    private(set) var state: simd_double2 = .zero

    /// Estimate error covariance P
    var estimateError: simd_double2x2 = matrix_identity_double2x2

    var position: Double { state[0] }
    var velocity: Double { state[1] }

    /// Process noise Q - symmetric, derived from constant-acceleration model
    /// Q = q * [[dt^4/4, dt^3/2], [dt^3/2, dt^2]]
    static func makeProcessNoise(dt: Double, q: Double) -> simd_double2x2 {
        let dt2 = dt * dt
        let dt3 = dt2 * dt
        let dt4 = dt3 * dt
        return .init(rows: [
            .init(q * dt4 / 4, q * dt3 / 2),
            .init(q * dt3 / 2, q * dt2)
        ])
    }

    init(timeStep: Double = 0.1, processNoiseIntensity: Double = 5.0, measurementNoiseVariance: Double = 1.0) {
        self.timeStep = timeStep
        self.measurementNoiseVariance = measurementNoiseVariance
        self.processNoise = KalmanFilter.makeProcessNoise(dt: timeStep, q: processNoiseIntensity)
    }

    /// Predict step: propagate state and covariance forward by dt
    /// controlInput is applied to position via velocity integration: pos += controlInput * dt
    mutating func predict(controlInput: Double) {
        let dt = timeStep
        let F: simd_double2x2 = .init(rows: [.init(1, dt), .init(0, 1)])

        state = F * state
        state[0] += controlInput * dt

        estimateError = (F * estimateError * F.transpose) + processNoise
    }

    /// Zero out velocity state and its covariance — used at low speed to prevent
    /// residual drift from propagating between GPS corrections
    mutating func resetVelocity() {
        state[1] = 0
        estimateError[0, 1] = 0
        estimateError[1, 0] = 0
        estimateError[1, 1] = 0.001
    }

    /// Update step: correct state with a measurement of position (state[0])
    /// Uses scalar observation model H = [1, 0] with Joseph form for numerical stability
    mutating func update(measurement: Double, noiseVariance: Double? = nil) {
        let R = noiseVariance ?? measurementNoiseVariance

        let innovation = measurement - state[0]
        let S = estimateError[0, 0] + R
        let K = simd_double2(estimateError[0, 0] / S, estimateError[1, 0] / S)

        state += K * innovation

        let IKH: simd_double2x2 = .init(rows: [
            .init(1 - K[0], 0),
            .init(-K[1], 1)
        ])
        estimateError = (IKH * estimateError * IKH.transpose)
        let KRKt: simd_double2x2 = .init(rows: [
            .init(K[0] * K[0] * R, K[0] * K[1] * R),
            .init(K[1] * K[0] * R, K[1] * K[1] * R)
        ])
        estimateError += KRKt
    }
}

// MARK: - Backward compatibility alias
typealias ExtendedKalmanFilter = KalmanFilter
