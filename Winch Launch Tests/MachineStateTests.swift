//
//  MachineStateTests.swift
//  Winch Launch Tests
//
//  Created by Nicola Ferruzzi on 09/03/26.
//

import XCTest
@testable import Winch_Launch


final class MachineStateTests: XCTestCase {

    // MARK: - Helpers

    let minSpeed = Measurement<UnitSpeed>(value: 70, unit: .kilometersPerHour)
    let maxSpeed = Measurement<UnitSpeed>(value: 110, unit: .kilometersPerHour)

    func makeSpeed(_ kmh: Double, at time: TimeInterval = 0) -> DataPointSpeed {
        .init(timestamp: .relative(time),
              value: .init(value: kmh, unit: .kilometersPerHour).converted(to: .metersPerSecond))
    }

    func makeAltitude(_ meters: Double, at time: TimeInterval = 0) -> DataPointAltitude {
        .init(timestamp: .relative(time), value: .init(value: meters, unit: .meters))
    }

    func transition(_ info: MachineInfo, speed: DataPointSpeed, altitude: DataPointAltitude) -> MachineInfo {
        MachineStateService.transition(
            currentInfo: info,
            speed: speed,
            altitude: altitude,
            minSpeed: minSpeed,
            maxSpeed: maxSpeed
        )
    }

    func waitingInfo(at time: TimeInterval = 0) -> MachineInfo {
        .init(state: .waiting, stateTimestamp: .relative(time))
    }

    // MARK: - Basic Transitions

    func testWaitingToTakingOff() {
        let info = waitingInfo()
        let result = transition(info, speed: makeSpeed(15), altitude: makeAltitude(0))
        XCTAssertEqual(result.state, .takingOff, "Should transition to takingOff when speed > 10 km/h")
        XCTAssertNotNil(result.takeOffAltitude)
    }

    func testWaitingStaysWaiting() {
        let info = waitingInfo()
        let result = transition(info, speed: makeSpeed(5), altitude: makeAltitude(0))
        XCTAssertEqual(result.state, .waiting, "Should stay waiting when speed < 10 km/h")
    }

    func testTakingOffToMinSpeedReached() {
        let info = MachineInfo(state: .takingOff, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(75), altitude: makeAltitude(5))
        XCTAssertEqual(result.state, .minSpeedReached)
    }

    func testTakingOffStaysBelowMinSpeed() {
        let info = MachineInfo(state: .takingOff, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(50), altitude: makeAltitude(2))
        XCTAssertEqual(result.state, .takingOff, "Should stay takingOff when below minSpeed")
    }

    // MARK: - Always pass through minSpeedReached

    func testTakingOffAlwaysPassesThroughMinSpeed() {
        // Even if speed jumps directly above maxSpeed, must go through minSpeedReached first
        let info = MachineInfo(state: .takingOff, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(120), altitude: makeAltitude(10))
        XCTAssertEqual(result.state, .minSpeedReached,
                       "Must pass through minSpeedReached even when speed > maxSpeed")
    }

    // MARK: - minSpeedReached transitions

    func testMinSpeedReachedToMaxSpeed() {
        let info = MachineInfo(state: .minSpeedReached, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(115), altitude: makeAltitude(20))
        XCTAssertEqual(result.state, .maxSpeedReached)
    }

    func testMinSpeedReachedStaysWithSmallDrop() {
        // Speed drops just below minSpeed but within hysteresis (5 km/h) — should NOT transition
        let info = MachineInfo(state: .minSpeedReached, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(68), altitude: makeAltitude(20))
        XCTAssertEqual(result.state, .minSpeedReached,
                       "Should NOT transition to minSpeedLost within hysteresis band")
    }

    func testMinSpeedReachedToLostBeyondHysteresis() {
        // Speed drops clearly below minSpeed - hysteresis (70 - 5 = 65)
        let info = MachineInfo(state: .minSpeedReached, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(60), altitude: makeAltitude(20))
        XCTAssertEqual(result.state, .minSpeedLost,
                       "Should transition to minSpeedLost when clearly below threshold")
    }

    // MARK: - minSpeedLost transitions

    func testMinSpeedLostStaysWithSmallRecovery() {
        // Speed recovers to just above minSpeed but within hysteresis — should NOT transition back
        let info = MachineInfo(state: .minSpeedLost, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(72), altitude: makeAltitude(20))
        XCTAssertEqual(result.state, .minSpeedLost,
                       "Should NOT transition back within hysteresis band")
    }

    func testMinSpeedLostToReachedBeyondHysteresis() {
        // Speed recovers clearly above minSpeed + hysteresis (70 + 5 = 75)
        let info = MachineInfo(state: .minSpeedLost, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(80), altitude: makeAltitude(20))
        XCTAssertEqual(result.state, .minSpeedReached,
                       "Should transition back when clearly above threshold")
    }

    func testMinSpeedLostToMaxSpeed() {
        let info = MachineInfo(state: .minSpeedLost, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(115), altitude: makeAltitude(20))
        XCTAssertEqual(result.state, .maxSpeedReached)
    }

    // MARK: - maxSpeedReached transitions (the bug fix)

    func testMaxSpeedToMinSpeedLost() {
        // Speed drops below minSpeed — should go to minSpeedLost, NOT minSpeedReached
        let info = MachineInfo(state: .maxSpeedReached, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(60), altitude: makeAltitude(50))
        XCTAssertEqual(result.state, .minSpeedLost,
                       "maxSpeedReached → below minSpeed should be minSpeedLost, not minSpeedReached")
    }

    func testMaxSpeedToMinSpeedReached() {
        // Speed drops below maxSpeed but still above minSpeed
        let info = MachineInfo(state: .maxSpeedReached, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(90), altitude: makeAltitude(50))
        XCTAssertEqual(result.state, .minSpeedReached)
    }

    func testMaxSpeedStaysWithSmallDrop() {
        // Speed drops just below maxSpeed but within hysteresis — should stay
        let info = MachineInfo(state: .maxSpeedReached, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))
        let result = transition(info, speed: makeSpeed(108), altitude: makeAltitude(50))
        XCTAssertEqual(result.state, .maxSpeedReached,
                       "Should stay maxSpeedReached within hysteresis band")
    }

    // MARK: - Hysteresis prevents oscillation

    func testNoChatterAroundMinSpeed() {
        var info = MachineInfo(state: .minSpeedReached, stateTimestamp: .relative(0), takeOffAltitude: makeAltitude(0))

        // Simulate speed oscillating around minSpeed (70 km/h) ± 3 km/h
        let oscillatingSpeeds: [Double] = [72, 68, 71, 67, 73, 69, 70, 68, 72, 67]
        var stateChanges = 0

        for (i, kmh) in oscillatingSpeeds.enumerated() {
            let newInfo = transition(info, speed: makeSpeed(kmh, at: Double(i)), altitude: makeAltitude(20))
            if newInfo.state != info.state {
                stateChanges += 1
            }
            info = newInfo
        }

        XCTAssertEqual(stateChanges, 0,
                       "Hysteresis should prevent any state changes with ±3 km/h oscillation around minSpeed")
    }

    // MARK: - Abort and completion

    func testAbortWhenSlowAndLow() {
        let info = MachineInfo(state: .minSpeedReached, stateTimestamp: .relative(0),
                               takeOffAltitude: makeAltitude(100, at: 0))
        // 15 seconds after takeoff, slow and at same altitude
        let result = transition(info, speed: makeSpeed(5, at: 15), altitude: makeAltitude(100.5))
        XCTAssertEqual(result.state, .aborted)
    }

    func testNoAbortBeforeTimeout() {
        let info = MachineInfo(state: .minSpeedReached, stateTimestamp: .relative(0),
                               takeOffAltitude: makeAltitude(100, at: 0))
        // Only 5 seconds after takeoff — too early for abort
        let result = transition(info, speed: makeSpeed(5, at: 5), altitude: makeAltitude(100.5))
        XCTAssertNotEqual(result.state, .aborted, "Should not abort before 10s timeout")
    }

    func testCompletionAfter40Seconds() {
        let info = MachineInfo(state: .minSpeedReached, stateTimestamp: .relative(0),
                               takeOffAltitude: makeAltitude(100, at: 0))
        let result = transition(info, speed: makeSpeed(80, at: 45), altitude: makeAltitude(300))
        XCTAssertEqual(result.state, .completed)
    }

    // MARK: - Full launch scenario

    func testNormalLaunchSequence() {
        var info = waitingInfo()
        var states: [MachineState] = [info.state]

        // Ground roll: accelerating
        for t in 1...5 {
            let speed = Double(t) * 15.0 // 15, 30, 45, 60, 75 km/h
            info = transition(info, speed: makeSpeed(speed, at: Double(t)), altitude: makeAltitude(0, at: Double(t)))
            states.append(info.state)
        }

        // Climb: speed increases to cruise
        for t in 6...15 {
            info = transition(info, speed: makeSpeed(90, at: Double(t)), altitude: makeAltitude(Double(t) * 10))
            states.append(info.state)
        }

        // Completed after 40s
        info = transition(info, speed: makeSpeed(85, at: 45), altitude: makeAltitude(250))
        states.append(info.state)

        XCTAssertTrue(states.contains(.waiting))
        XCTAssertTrue(states.contains(.takingOff))
        XCTAssertTrue(states.contains(.minSpeedReached))
        XCTAssertTrue(states.contains(.completed))
    }

    func testLaunchWithSpeedLossAndRecovery() {
        var info = waitingInfo()

        // Start and reach minSpeed
        info = transition(info, speed: makeSpeed(15, at: 1), altitude: makeAltitude(0, at: 1))
        XCTAssertEqual(info.state, .takingOff)

        info = transition(info, speed: makeSpeed(80, at: 3), altitude: makeAltitude(10, at: 3))
        XCTAssertEqual(info.state, .minSpeedReached)

        // Speed drops clearly below minSpeed (below hysteresis)
        info = transition(info, speed: makeSpeed(60, at: 5), altitude: makeAltitude(30, at: 5))
        XCTAssertEqual(info.state, .minSpeedLost)

        // Speed recovers clearly above minSpeed (above hysteresis)
        info = transition(info, speed: makeSpeed(80, at: 7), altitude: makeAltitude(50, at: 7))
        XCTAssertEqual(info.state, .minSpeedReached)
    }

    func testLaunchWithOverspeedThenRecovery() {
        var info = waitingInfo()

        info = transition(info, speed: makeSpeed(15, at: 1), altitude: makeAltitude(0, at: 1))
        info = transition(info, speed: makeSpeed(80, at: 3), altitude: makeAltitude(10, at: 3))
        XCTAssertEqual(info.state, .minSpeedReached)

        // Overspeed
        info = transition(info, speed: makeSpeed(115, at: 5), altitude: makeAltitude(50, at: 5))
        XCTAssertEqual(info.state, .maxSpeedReached)

        // Speed recovers to normal range (below maxSpeed - hysteresis)
        info = transition(info, speed: makeSpeed(90, at: 7), altitude: makeAltitude(80, at: 7))
        XCTAssertEqual(info.state, .minSpeedReached)

        // Completed
        info = transition(info, speed: makeSpeed(85, at: 45), altitude: makeAltitude(250, at: 45))
        XCTAssertEqual(info.state, .completed)
    }
}
