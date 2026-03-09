//
//  WingDropTests.swift
//  Winch Launch Tests
//
//  Created by Nicola Ferruzzi on 09/03/26.
//

import XCTest
@testable import Winch_Launch


final class WingDropTests: XCTestCase {

    typealias VM = AHServiceViewModel

    // MARK: - Detection during monitored states

    func testDetectedDuringTakingOff() {
        XCTAssertTrue(VM.shouldAnnounceWingDrop(rollDegrees: 20, state: .takingOff, alreadyAnnounced: false))
    }

    func testDetectedDuringMinSpeedReached() {
        XCTAssertTrue(VM.shouldAnnounceWingDrop(rollDegrees: 20, state: .minSpeedReached, alreadyAnnounced: false))
    }

    func testDetectedDuringMinSpeedLost() {
        XCTAssertTrue(VM.shouldAnnounceWingDrop(rollDegrees: 20, state: .minSpeedLost, alreadyAnnounced: false))
    }

    // MARK: - Negative roll (opposite wing)

    func testDetectedWithNegativeRoll() {
        XCTAssertTrue(VM.shouldAnnounceWingDrop(rollDegrees: -20, state: .takingOff, alreadyAnnounced: false))
    }

    // MARK: - Not triggered in non-monitored states

    func testNotTriggeredDuringWaiting() {
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 30, state: .waiting, alreadyAnnounced: false))
    }

    func testNotTriggeredDuringMaxSpeedReached() {
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 30, state: .maxSpeedReached, alreadyAnnounced: false))
    }

    func testNotTriggeredDuringCompleted() {
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 30, state: .completed, alreadyAnnounced: false))
    }

    func testNotTriggeredDuringAborted() {
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 30, state: .aborted, alreadyAnnounced: false))
    }

    // MARK: - Already announced

    func testNotTriggeredWhenAlreadyAnnounced() {
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 30, state: .takingOff, alreadyAnnounced: true))
    }

    // MARK: - Below threshold

    func testNotTriggeredBelowThreshold() {
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 10, state: .takingOff, alreadyAnnounced: false))
    }

    func testNotTriggeredAtExactThreshold() {
        // abs(roll) must be > threshold, not >=
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 15, state: .takingOff, alreadyAnnounced: false))
    }

    func testTriggeredJustAboveThreshold() {
        XCTAssertTrue(VM.shouldAnnounceWingDrop(rollDegrees: 15.1, state: .takingOff, alreadyAnnounced: false))
    }

    // MARK: - Custom threshold

    func testCustomThreshold() {
        XCTAssertTrue(VM.shouldAnnounceWingDrop(rollDegrees: 11, state: .takingOff, alreadyAnnounced: false, thresholdDegrees: 10))
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 9, state: .takingOff, alreadyAnnounced: false, thresholdDegrees: 10))
    }

    // MARK: - Zero roll

    func testZeroRollNotTriggered() {
        XCTAssertFalse(VM.shouldAnnounceWingDrop(rollDegrees: 0, state: .takingOff, alreadyAnnounced: false))
    }
}
