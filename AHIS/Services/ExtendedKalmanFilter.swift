//
//  KalmanFilter.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 16/08/23.
//
//  Linear Kalman Filter for fusing GPS speed (1Hz) with accelerometer (10Hz).
//  State vector: [velocity, acceleration]
//
//  Reference material for future improvements
//  https://www.youtube.com/watch?v=HkYRJJoyBwQ
//  https://ardupilot.org/dev/docs/extended-kalman-filter.html


import Foundation
import simd


struct KalmanFilter {
    enum Constant {
        static let timeStep: Double = 0.1
        /// Process noise intensity (tunable)
        static let processNoiseIntensity: Double = 5.0
        /// Measurement noise variance for GPS velocity
        static let measurementNoiseVariance: Double = 1.0
    }

    /// State vector: [velocity, acceleration]
    private(set) var state: simd_double2 = .zero

    /// Estimate error covariance P
    var estimateError: simd_double2x2 = matrix_identity_double2x2

    var velocity: Double { state[0] }
    var acceleration: Double { state[1] }

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

    let processNoise: simd_double2x2 = KalmanFilter.makeProcessNoise(
        dt: Constant.timeStep,
        q: Constant.processNoiseIntensity
    )

    /// Predict step: propagate state and covariance forward by dt using current acceleration
    /// Call this at accelerometer rate (10Hz)
    mutating func predict(controlAcceleration: Double) {
        let dt = Constant.timeStep
        let F: simd_double2x2 = .init(rows: [.init(1, dt), .init(0, 1)])

        // State prediction: v' = v + a*dt, a' = a (constant acceleration model)
        // Plus control input: apply measured acceleration
        state = F * state
        state[0] += controlAcceleration * dt

        // Covariance prediction
        estimateError = (F * estimateError * F.transpose) + processNoise
    }

    /// Update step: correct state with GPS velocity measurement
    /// Uses scalar observation model H = [1, 0] with Joseph form for numerical stability
    mutating func update(velocityMeasurement: Double) {
        let R = Constant.measurementNoiseVariance

        // Innovation (residual): z - H*x, where H = [1, 0]
        let innovation = velocityMeasurement - state[0]

        // Innovation covariance: S = H*P*H' + R = P[0,0] + R (scalar)
        let S = estimateError[0, 0] + R

        // Kalman gain: K = P*H'/S = [P[0,0]/S, P[1,0]/S]
        let K = simd_double2(estimateError[0, 0] / S, estimateError[1, 0] / S)

        // State correction
        state += K * innovation

        // Covariance update using Joseph form: P = (I - K*H)*P*(I - K*H)' + K*R*K'
        let IKH: simd_double2x2 = .init(rows: [
            .init(1 - K[0], 0),
            .init(-K[1], 1)
        ])
        estimateError = (IKH * estimateError * IKH.transpose)
        // Add K*R*K' term
        let KRKt: simd_double2x2 = .init(rows: [
            .init(K[0] * K[0] * R, K[0] * K[1] * R),
            .init(K[1] * K[0] * R, K[1] * K[1] * R)
        ])
        estimateError += KRKt
    }
}

// MARK: - Backward compatibility alias
typealias ExtendedKalmanFilter = KalmanFilter
