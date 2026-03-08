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
        XCTAssertEqual(kf.position, 0.0)
        XCTAssertEqual(kf.velocity, 0.0)
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
        let trace = Q[0, 0] + Q[1, 1]
        let det = Q[0, 0] * Q[1, 1] - Q[0, 1] * Q[1, 0]
        XCTAssertGreaterThan(trace, 0, "Q trace must be positive")
        XCTAssertGreaterThanOrEqual(det, -1e-15, "Q determinant must be non-negative")
    }

    // MARK: - Custom Parameters

    func testCustomParameters() {
        let kf = KalmanFilter(timeStep: 0.05, processNoiseIntensity: 10.0, measurementNoiseVariance: 2.0)
        XCTAssertEqual(kf.timeStep, 0.05)
        XCTAssertEqual(kf.measurementNoiseVariance, 2.0)
    }

    // MARK: - Predict Only

    func testPredictWithZeroInput() {
        var kf = KalmanFilter()
        for _ in 0..<100 {
            kf.predict(controlInput: 0.0)
        }
        XCTAssertEqual(kf.position, 0.0, accuracy: 1e-10,
                       "Position should stay 0 with zero input")
    }

    func testPredictWithConstantInput() {
        var kf = KalmanFilter()
        let input = 2.0
        let steps = 100

        for _ in 0..<steps {
            kf.predict(controlInput: input)
        }

        // Expected position: input * dt * steps = 2 * 0.1 * 100 = 20
        let expected = input * kf.timeStep * Double(steps)
        XCTAssertEqual(kf.position, expected, accuracy: 0.1,
                       "Position should grow linearly with constant input")
    }

    func testCovarianceGrowsDuringPrediction() {
        var kf = KalmanFilter()
        let initialP00 = kf.estimateError[0, 0]

        for _ in 0..<10 {
            kf.predict(controlInput: 0.0)
        }

        XCTAssertGreaterThan(kf.estimateError[0, 0], initialP00,
                             "Covariance should grow during prediction-only phase")
    }

    // MARK: - Update Only

    func testUpdateConvergesToMeasurement() {
        var kf = KalmanFilter()
        let trueValue = 15.0

        for _ in 0..<50 {
            kf.predict(controlInput: 0.0)
            kf.update(measurement: trueValue)
        }

        XCTAssertEqual(kf.position, trueValue, accuracy: 0.5,
                       "Filter should converge to repeated measurement")
    }

    func testCovarianceShrinksDuringUpdate() {
        var kf = KalmanFilter()

        for _ in 0..<10 {
            kf.predict(controlInput: 0.0)
        }
        let beforeP00 = kf.estimateError[0, 0]

        kf.update(measurement: 10.0)
        XCTAssertLessThan(kf.estimateError[0, 0], beforeP00,
                          "Covariance should shrink after a measurement update")
    }

    // MARK: - Speed KF: Predict-Update Cycle (realistic scenario)

    func testSpeedKFConverges() {
        var kf = KalmanFilter(timeStep: 0.1, processNoiseIntensity: 5.0, measurementNoiseVariance: 1.0)
        let trueSpeed = 20.0

        for second in 0..<10 {
            let noisyGPS = trueSpeed + Double.random(in: -1.0...1.0)
            kf.update(measurement: noisyGPS)

            for _ in 0..<10 {
                let noisyAccel = Double.random(in: -0.2...0.2)
                kf.predict(controlInput: noisyAccel)
            }

            if second > 5 {
                XCTAssertEqual(kf.position, trueSpeed, accuracy: 3.0,
                               "Filtered speed should be near true speed after convergence")
            }
        }
    }

    func testAcceleratingLaunchProfile() {
        var kf = KalmanFilter(timeStep: 0.1, processNoiseIntensity: 5.0, measurementNoiseVariance: 1.0)
        let launchAcceleration = 3.0

        for second in 0..<5 {
            let expectedSpeed = launchAcceleration * Double(second)
            let noisyGPS = expectedSpeed + Double.random(in: -0.5...0.5)
            kf.update(measurement: noisyGPS)

            for _ in 0..<10 {
                let noisyAccel = launchAcceleration + Double.random(in: -0.3...0.3)
                kf.predict(controlInput: noisyAccel)
            }
        }

        XCTAssertGreaterThan(kf.position, 10.0)
        XCTAssertLessThan(kf.position, 25.0)
    }

    // MARK: - Altitude KF

    func testAltitudeKFSmooths() {
        var kf = KalmanFilter(timeStep: 0.1, processNoiseIntensity: 2.0, measurementNoiseVariance: 0.5)
        let trueAltitude = 100.0 // meters
        var altitudes: [Double] = []

        // Simulate: barometer at ~1Hz, vertical accel at 10Hz, constant altitude
        for second in 0..<10 {
            let noisyBaro = trueAltitude + Double.random(in: -0.3...0.3)
            kf.update(measurement: noisyBaro)

            for step in 0..<10 {
                let noisyAccel = Double.random(in: -0.1...0.1)
                kf.predict(controlInput: noisyAccel)
                altitudes.append(kf.position)
            }
        }

        // Should have 100 altitude samples (10Hz for 10s)
        XCTAssertEqual(altitudes.count, 100)

        // After convergence, altitude should be close to true value
        let lastAltitudes = altitudes.suffix(20)
        for alt in lastAltitudes {
            XCTAssertEqual(alt, trueAltitude, accuracy: 2.0,
                           "Altitude should converge near true value")
        }
    }

    func testAltitudeKFClimbingProfile() {
        var kf = KalmanFilter(timeStep: 0.1, processNoiseIntensity: 2.0, measurementNoiseVariance: 0.5)
        let climbRate = 5.0 // m/s vertical speed
        let verticalAccel = 0.0 // constant climb, no acceleration

        for second in 0..<10 {
            let expectedAlt = climbRate * Double(second)
            let noisyBaro = expectedAlt + Double.random(in: -0.5...0.5)
            kf.update(measurement: noisyBaro)

            for _ in 0..<10 {
                kf.predict(controlInput: verticalAccel + Double.random(in: -0.1...0.1))
            }
        }

        // After 10s at 5m/s, expect ~50m
        XCTAssertGreaterThan(kf.position, 30.0, "Altitude should be substantial after climb")
        XCTAssertLessThan(kf.position, 70.0, "Altitude should not overshoot")
        // Velocity state should approximate climb rate
        XCTAssertGreaterThan(kf.velocity, 2.0, "Vertical speed should reflect climb")
    }

    // MARK: - Numerical Stability

    func testCovarianceRemainsSymmetric() {
        var kf = KalmanFilter()

        for i in 0..<200 {
            let input = sin(Double(i) * 0.1) * 2.0
            kf.predict(controlInput: input)

            if i % 10 == 0 {
                kf.update(measurement: Double(i) * 0.05)
            }
        }

        let P = kf.estimateError
        XCTAssertEqual(P[0, 1], P[1, 0], accuracy: 1e-10,
                       "Covariance must remain symmetric after many iterations")
    }

    func testCovarianceRemainsPositiveDefinite() {
        var kf = KalmanFilter()

        for i in 0..<200 {
            kf.predict(controlInput: Double.random(in: -5...5))

            if i % 10 == 0 {
                kf.update(measurement: Double.random(in: 0...30))
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
        kf.predict(controlInput: 5.0)
        kf.update(measurement: 10.0)

        kf = KalmanFilter()
        XCTAssertEqual(kf.position, 0.0)
        XCTAssertEqual(kf.velocity, 0.0)
        XCTAssertEqual(kf.estimateError, matrix_identity_double2x2)
    }

    // MARK: - Edge Cases

    func testVeryLargeMeasurement() {
        var kf = KalmanFilter()
        kf.update(measurement: 1000.0)
        XCTAssertFalse(kf.position.isNaN, "Filter should handle large measurements")
        XCTAssertFalse(kf.position.isInfinite, "Filter should handle large measurements")
    }

    func testNegativeValues() {
        var kf = KalmanFilter()
        for _ in 0..<10 {
            kf.predict(controlInput: 0.0)
            kf.update(measurement: -5.0)
        }
        XCTAssertEqual(kf.position, -5.0, accuracy: 1.0,
                       "Filter should handle negative measurements")
    }

    // MARK: - Flight Path Projection Helpers

    func testFlightPathAccelerationAtZeroPitch() {
        let pitch = 0.0
        let ax = 2.0, ay = 0.0, az = 0.0
        let aHorizontal = sqrt(ax * ax + ay * ay)
        let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
        XCTAssertEqual(aFlightPath, 2.0, accuracy: 1e-10)
    }

    func testFlightPathAccelerationAt45Degrees() {
        let pitch = Double.pi / 4
        let ax = 1.0, ay = 0.0, az = 1.0
        let aHorizontal = sqrt(ax * ax + ay * ay)
        let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
        XCTAssertEqual(aFlightPath, sqrt(2.0), accuracy: 1e-10)
    }

    func testFlightPathAccelerationAt90Degrees() {
        let pitch = Double.pi / 2
        let ax = 0.0, ay = 0.0, az = 3.0
        let aHorizontal = sqrt(ax * ax + ay * ay)
        let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
        XCTAssertEqual(aFlightPath, 3.0, accuracy: 1e-10)
    }

    func testGPSCorrectionAtZeroPitch() {
        let groundSpeed = 20.0
        let cosPitch = cos(0.0)
        XCTAssertEqual(groundSpeed / cosPitch, 20.0, accuracy: 1e-10)
    }

    func testGPSCorrectionAt45Degrees() {
        let groundSpeed = 14.14
        let cosPitch = cos(Double.pi / 4)
        XCTAssertEqual(groundSpeed / cosPitch, 20.0, accuracy: 0.1)
    }

    func testGPSCorrectionClampedAtExtremePitch() {
        let groundSpeed = 10.0
        let pitch = 80.0 * Double.pi / 180
        let cosPitch = cos(pitch)
        XCTAssertLessThan(abs(cosPitch), 0.3, "cos(80°) should be < 0.3")
        XCTAssertEqual(groundSpeed / 0.3, 33.33, accuracy: 0.1)
    }
}
