//
//  SettingsUITests.swift
//  YippyUITests
//

import XCTest

class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        // Nothing to clean up after a failure
        continueAfterFailure = false
        
        // Set full access control
        AccessControlMock.setControlGranted(true)
        
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--test-dir=Empty")
        app.launchEnvironment["SRCROOT"] = ProcessInfo.processInfo.environment["SRCROOT"]
    }
    
    func openIgnoredAppsTab() {
        app.statusItemButton.click()
        app.menus.menuItems["Preferences..."].click()
        
        let tab = app.toolbars.buttons["Ignored Apps"]
        XCTAssertTrue(tab.waitForExistence(timeout: 2))
        tab.click()
    }
    
    func testIgnoredAppsTab() {
        app.launch()
        openIgnoredAppsTab()
        
        // The list starts empty, with add and remove buttons
        let table = app.tables[Accessibility.identifiers.ignoredAppsTableView]
        XCTAssertTrue(table.waitForExistence(timeout: 2))
        XCTAssertEqual(table.tableRows.count, 0)
        XCTAssertTrue(app.descendants(matching: .any)[Accessibility.identifiers.ignoredAppsAddRemoveControl].exists)
        
        let screenshot = XCTAttachment(screenshot: app.windows["Ignored Apps"].screenshot())
        screenshot.name = "Ignored Apps settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    
    func testIgnoredAppsListAndRemove() {
        app.launchArguments.append("--Settings.testData=ignoredApps")
        app.launch()
        openIgnoredAppsTab()
        
        // Installed apps show their name, others their bundle id
        let table = app.tables[Accessibility.identifiers.ignoredAppsTableView]
        XCTAssertTrue(table.waitForExistence(timeout: 2))
        XCTAssertEqual(table.tableRows.count, 2)
        XCTAssertTrue(table.staticTexts["TextEdit"].exists)
        XCTAssertTrue(table.staticTexts["com.example.notInstalled"].exists)
        
        let screenshot = XCTAttachment(screenshot: app.windows["Ignored Apps"].screenshot())
        screenshot.name = "Ignored Apps settings with apps"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        
        // Remove the first
        table.tableRows.element(boundBy: 0).click()
        app.descendants(matching: .any)[Accessibility.identifiers.ignoredAppsAddRemoveControl].buttons.element(boundBy: 1).click()
        XCTAssertEqual(table.tableRows.count, 1)
        XCTAssertFalse(table.staticTexts["TextEdit"].exists)
    }
}
