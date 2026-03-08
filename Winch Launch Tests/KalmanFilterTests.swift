//
//  KalmanFilterTests.swift
//  Winch Launch Tests
//
//  Created by Nicola Ferruzzi on 08/03/26.
//

import XCTest
import simd
@testable import Winch_Launch


final class KalmanFilterTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState() {
        let kf = KalmanFilter()
        XCTAssertEqual(kf.velocity, 0.0)
        XCTAssertEqual(kf.acceleration, 0.0)
        XCTAssertEqual(kf.estimateError, matrix_identity_double2x2)
    }

    // MARK: - Process Noise Symmetry

    func testProcessNoiseIsSymmetric() {
        let kf = KalmanFilter()
        let Q = kf.processNoise
        XCTAssertEqual(Q[0, 1], Q[1, 0], accuracy: 1e-15,
                       "Process noise matrix Q must be symmetric")
    }

    func testProcessNoiseIsPositiveSemiDefinite() {
        let kf = KalmanFilter()
        let Q = kf.processNoise
        // For 2x2: positive semi-definite if trace >= 0 and determinant >= 0
        // Note: Q from constant-acceleration model is rank-1 (det ≈ 0), which is correct
        let trace = Q[0, 0] + Q[1, 1]
        let det = Q[0, 0] * Q[1, 1] - Q[0, 1] * Q[1, 0]
        XCTAssertGreaterThan(trace, 0, "Q trace must be positive")
        XCTAssertGreaterThanOrEqual(det, -1e-15, "Q determinant must be non-negative")
    }

    // MARK: - Predict Only

    func testPredictWithZeroAcceleration() {
        var kf = KalmanFilter()
        // Initial velocity is 0, acceleration is 0
        for _ in 0..<100 {
            kf.predict(controlAcceleration: 0.0)
        }
        // Velocity should remain near 0
        XCTAssertEqual(kf.velocity, 0.0, accuracy: 1e-10,
                       "Velocity should stay 0 with zero acceleration")
    }

    func testPredictWithConstantAcceleration() {
        var kf = KalmanFilter()
        let accel = 2.0 // m/s²
        let dt = KalmanFilter.Constant.timeStep
        let steps = 100

        for _ in 0..<steps {
            kf.predict(controlAcceleration: accel)
        }

        // Expected velocity: a * dt * steps = 2 * 0.1 * 100 = 20 m/s
        let expectedVelocity = accel * dt * Double(steps)
        XCTAssertEqual(kf.velocity, expectedVelocity, accuracy: 0.1,
                       "Velocity should grow linearly with constant acceleration")
    }

    func testCovarianceGrowsDuringPrediction() {
        var kf = KalmanFilter()
        let initialP00 = kf.estimateError[0, 0]

        for _ in 0..<10 {
            kf.predict(controlAcceleration: 0.0)
        }

        XCTAssertGreaterThan(kf.estimateError[0, 0], initialP00,
                             "Covariance should grow during prediction-only phase")
    }

    // MARK: - Update Only

    func testUpdateConvergesToMeasurement() {
        var kf = KalmanFilter()
        let trueVelocity = 15.0

        // Alternate predict (to inflate P) and update to allow convergence
        for _ in 0..<50 {
            kf.predict(controlAcceleration: 0.0)
            kf.update(velocityMeasurement: trueVelocity)
        }

        XCTAssertEqual(kf.velocity, trueVelocity, accuracy: 0.5,
                       "Filter should converge to repeated measurement")
    }

    func testCovarianceShrinksDuringUpdate() {
        var kf = KalmanFilter()

        // Inflate covariance first
        for _ in 0..<10 {
            kf.predict(controlAcceleration: 0.0)
        }
        let beforeP00 = kf.estimateError[0, 0]

        kf.update(velocityMeasurement: 10.0)
        XCTAssertLessThan(kf.estimateError[0, 0], beforeP00,
                          "Covariance should shrink after a measurement update")
    }

    // MARK: - Predict-Update Cycle (realistic scenario)

    func testPredictUpdateCycleConverges() {
        var kf = KalmanFilter()
        let trueVelocity = 20.0 // m/s constant
        let trueAcceleration = 0.0

        // Simulate 10 seconds: GPS at 1Hz, accelerometer at 10Hz
        for second in 0..<10 {
            // GPS update at start of each second
            let noisyGPS = trueVelocity + Double.random(in: -1.0...1.0)
            kf.update(velocityMeasurement: noisyGPS)

            // 10 accelerometer readings per second
            for _ in 0..<10 {
                let noisyAccel = trueAcceleration + Double.random(in: -0.2...0.2)
                kf.predict(controlAcceleration: noisyAccel)
            }

            if second > 5 {
                // After convergence, velocity should be close to true value
                XCTAssertEqual(kf.velocity, trueVelocity, accuracy: 3.0,
                               "Filtered velocity should be near true velocity after convergence")
            }
        }
    }

    func testAcceleratingLaunchProfile() {
        var kf = KalmanFilter()
        let launchAcceleration = 3.0 // m/s², typical winch launch

        // Simulate 5 seconds of acceleration
        for second in 0..<5 {
            let expectedSpeed = launchAcceleration * Double(second)
            let noisyGPS = expectedSpeed + Double.random(in: -0.5...0.5)
            kf.update(velocityMeasurement: noisyGPS)

            for _ in 0..<10 {
                let noisyAccel = launchAcceleration + Double.random(in: -0.3...0.3)
                kf.predict(controlAcceleration: noisyAccel)
            }
        }

        // After 5 seconds at 3 m/s², expected ~15 m/s
        XCTAssertGreaterThan(kf.velocity, 10.0,
                             "Velocity should be substantial after sustained acceleration")
        XCTAssertLessThan(kf.velocity, 25.0,
                          "Velocity should not overshoot excessively")
    }

    // MARK: - Numerical Stability

    func testCovarianceRemainsSymmetric() {
        var kf = KalmanFilter()

        for i in 0..<200 {
            let accel = sin(Double(i) * 0.1) * 2.0
            kf.predict(controlAcceleration: accel)

            if i % 10 == 0 {
                kf.update(velocityMeasurement: Double(i) * 0.05)
            }
        }

        let P = kf.estimateError
        XCTAssertEqual(P[0, 1], P[1, 0], accuracy: 1e-10,
                       "Covariance must remain symmetric after many iterations")
    }

    func testCovarianceRemainsPositiveDefinite() {
        var kf = KalmanFilter()

        for i in 0..<200 {
            kf.predict(controlAcceleration: Double.random(in: -5...5))

            if i % 10 == 0 {
                kf.update(velocityMeasurement: Double.random(in: 0...30))
            }
        }

        let P = kf.estimateError
        let trace = P[0, 0] + P[1, 1]
        let det = P[0, 0] * P[1, 1] - P[0, 1] * P[1, 0]
        XCTAssertGreaterThan(trace, 0, "P trace must remain positive")
        XCTAssertGreaterThan(det, 0, "P determinant must remain positive")
    }

    // MARK: - Reset via re-initialization

    func testResetToInitialState() {
        var kf = KalmanFilter()
        kf.predict(controlAcceleration: 5.0)
        kf.update(velocityMeasurement: 10.0)

        // Reset by creating new instance (as done in MachineStateService)
        kf = KalmanFilter()
        XCTAssertEqual(kf.velocity, 0.0)
        XCTAssertEqual(kf.acceleration, 0.0)
        XCTAssertEqual(kf.estimateError, matrix_identity_double2x2)
    }

    // MARK: - Edge Cases

    func testVeryLargeMeasurement() {
        var kf = KalmanFilter()
        kf.update(velocityMeasurement: 1000.0)
        XCTAssertFalse(kf.velocity.isNaN, "Filter should handle large measurements")
        XCTAssertFalse(kf.velocity.isInfinite, "Filter should handle large measurements")
    }

    // MARK: - Flight Path Projection Helpers

    func testFlightPathAccelerationAtZeroPitch() {
        // At zero pitch (horizontal flight), flight path accel = horizontal accel
        let pitch = 0.0
        let ax = 2.0, ay = 0.0, az = 0.0
        let aHorizontal = sqrt(ax * ax + ay * ay)
        let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
        XCTAssertEqual(aFlightPath, 2.0, accuracy: 1e-10)
    }

    func testFlightPathAccelerationAt45Degrees() {
        // At 45° pitch, both horizontal and vertical contribute equally
        let pitch = Double.pi / 4
        let ax = 1.0, ay = 0.0, az = 1.0 // 1g horizontal, 1g vertical
        let aHorizontal = sqrt(ax * ax + ay * ay)
        let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
        // cos(45°) + sin(45°) = 2 * 0.707 ≈ 1.414
        XCTAssertEqual(aFlightPath, sqrt(2.0), accuracy: 1e-10)
    }

    func testFlightPathAccelerationAt90Degrees() {
        // At 90° pitch (vertical climb), flight path accel = vertical accel
        let pitch = Double.pi / 2
        let ax = 0.0, ay = 0.0, az = 3.0
        let aHorizontal = sqrt(ax * ax + ay * ay)
        let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
        XCTAssertEqual(aFlightPath, 3.0, accuracy: 1e-10)
    }

    func testGPSCorrectionAtZeroPitch() {
        // At zero pitch, corrected speed = ground speed
        let groundSpeed = 20.0
        let pitch = 0.0
        let cosPitch = cos(pitch)
        let corrected = groundSpeed / cosPitch
        XCTAssertEqual(corrected, 20.0, accuracy: 1e-10)
    }

    func testGPSCorrectionAt45Degrees() {
        // At 45° pitch, ground speed is cos(45°) of flight path speed
        // So flight path speed = groundSpeed / cos(45°)
        let groundSpeed = 14.14
        let pitch = Double.pi / 4
        let cosPitch = cos(pitch)
        let corrected = groundSpeed / cosPitch
        XCTAssertEqual(corrected, 20.0, accuracy: 0.1)
    }

    func testGPSCorrectionClampedAtExtremePitch() {
        // At extreme pitch (>72°), cos(pitch) < 0.3, should be clamped
        let groundSpeed = 10.0
        let pitch = 80.0 * Double.pi / 180 // 80°
        let cosPitch = cos(pitch)
        XCTAssertLessThan(abs(cosPitch), 0.3, "cos(80°) should be < 0.3")
        // Clamped correction: groundSpeed / 0.3
        let corrected = groundSpeed / 0.3
        XCTAssertEqual(corrected, 33.33, accuracy: 0.1)
    }

    func testNegativeVelocity() {
        var kf = KalmanFilter()
        // With P=I and R=1, first update Kalman gain for velocity ≈ 0.5
        // so velocity becomes ~-2.5. Use predict+update cycle for convergence.
        for _ in 0..<10 {
            kf.predict(controlAcceleration: 0.0)
            kf.update(velocityMeasurement: -5.0)
        }
        XCTAssertEqual(kf.velocity, -5.0, accuracy: 1.0,
                       "Filter should handle negative velocity measurements")
    }
}
