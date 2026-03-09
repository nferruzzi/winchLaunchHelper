//
//  Winch_Launch_UITests.swift
//  Winch Launch UITests
//
//  Created by Nicola Ferruzzi on 21/09/23.il resetokquan
//

import XCTest


@MainActor
final class Winch_Launch_UITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        setupSnapshot(app)
        app.launchArguments += ["-replayTimeScale", "10", "-skipDisclaimer", "-autoReplay"]

        // Imperial units for English locale (mph + feet)
        if Snapshot.deviceLanguage.hasPrefix("en") {
            app.launchArguments += ["-unitSpeed", "mph", "-unitAltitude", "feets"]
        }

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

        // Take launch screenshots while climb is in progress
        // At 10x speed: each real second ≈ 10 sec simulation
        // Capture early to show mid-climb with altitude curve
        snapshot("01_Launch")

        sleep(1)
        snapshot("02_Simulation")

        // Open Settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button not found")
        settingsButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        snapshot("03_Settings")

        // Navigate to Alerts Settings
        let alertsButton = app.buttons["AlertsNavLink"]
        XCTAssertTrue(alertsButton.waitForExistence(timeout: 3), "Alerts button not found")
        alertsButton.tap()
        snapshot("04_AlertsSettings")
    }
}
