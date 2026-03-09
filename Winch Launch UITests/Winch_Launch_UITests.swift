//
//  Winch_Launch_UITests.swift
//  Winch Launch UITests
//
//  Created by Nicola Ferruzzi on 21/09/23.
//

import XCTest


@MainActor
final class Winch_Launch_UITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        setupSnapshot(app)
        app.launchArguments += ["-replayTimeScale", "10", "-skipDisclaimer", "-autoReplay"]
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testScreenshots() throws {
        app.launch()

        _ = addUIInterruptionMonitor(withDescription: "Location Permission Alert") { (alertElement) -> Bool in
            alertElement.buttons["Allow Once"].tap()
            return true
        }

        // Tap to trigger any pending interruption monitor (e.g. location permission)
        app.tap()
        sleep(1)
        app.tap()

        // Open Settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button not found")
        settingsButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        snapshot("01_Settings")

        // Navigate to Alerts Settings
        let alertsButton = app.buttons["AlertsNavLink"]
        XCTAssertTrue(alertsButton.waitForExistence(timeout: 3), "Alerts button not found")
        alertsButton.tap()
        snapshot("02_AlertsSettings")

        // Go back to Settings
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Close Settings
        let closeButton = app.navigationBars.firstMatch.buttons.firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close settings button not found")
        closeButton.tap()

        // Replay is already running via -autoReplay, wait for mid-launch
        sleep(4)
        snapshot("03_Launch")

        sleep(3)
        snapshot("04_Simulation")
    }
}
