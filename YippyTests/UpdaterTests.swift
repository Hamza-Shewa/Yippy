//
//  UpdaterTests.swift
//  YippyTests
//

import XCTest
@testable import Yippy

class UpdaterTests: XCTestCase {
    
    func testNotConfiguredWithoutFeedAndKey() {
        XCTAssertFalse(Updater.isConfigured(infoDictionary: nil))
        XCTAssertFalse(Updater.isConfigured(infoDictionary: [:]))
        // As shipped in Info.plist until the release keys are filled in
        XCTAssertFalse(Updater.isConfigured(infoDictionary: ["SUFeedURL": "", "SUPublicEDKey": ""]))
        XCTAssertFalse(Updater.isConfigured(infoDictionary: ["SUFeedURL": "https://example.com/appcast.xml", "SUPublicEDKey": " "]))
        XCTAssertFalse(Updater.isConfigured(infoDictionary: ["SUPublicEDKey": "abc="]))
    }
    
    func testRequiresHttpsFeed() {
        XCTAssertFalse(Updater.isConfigured(infoDictionary: ["SUFeedURL": "http://example.com/appcast.xml", "SUPublicEDKey": "abc="]))
        XCTAssertTrue(Updater.isConfigured(infoDictionary: ["SUFeedURL": "https://example.com/appcast.xml", "SUPublicEDKey": "abc="]))
    }
    
    func testShippedInfoPlistLeavesUpdatesOff() {
        // The test host is the app, so this is the real Info.plist
        XCTAssertFalse(Updater.isConfigured(infoDictionary: Bundle.main.infoDictionary))
        XCTAssertFalse(Updater().isEnabled)
    }
}
