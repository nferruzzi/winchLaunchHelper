//
//  Winch_Launch_UITests.swift
//  Winch Launch UITests
//
//  Created by Nicola Ferruzzi on 21/09/23.
//

import XCTest


final class Winch_Launch_UITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        setupSnapshot(app)
        app.resetAuthorizationStatus(for: .location)

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        app.launch()
                
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        _ = addUIInterruptionMonitor(withDescription: "Location Permission Alert") { (alertElement) -> Bool in
            alertElement.buttons["Allow Once"].tap()
            return true
        }

        snapshot("Initial")
        app.buttons["Airplane Mode"].tap()
        snapshot("Settings")
        app.buttons["Replay Off"].tap()
        app.staticTexts["k2_apollonia_strong_wind_1"].tap()
        app.buttons["Left"].tap()
        sleep(50)
        snapshot("Simulation")
    }
}
