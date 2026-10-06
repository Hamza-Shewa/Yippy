//
//  SettingsTests.swift
//  YippyTests
//
//  Created by Matthew Davidson on 26/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy
@testable import RxRelay
@testable import RxTest
@testable import RxSwift

class SettingsTests: XCTestCase {
    
    var old: [String: Any]!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        old = UserDefaults.standard.blank()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        UserDefaults.standard.restore(from: old)
    }
    
    func testDefaultSettings() {
        // 1. Given nothing
        
        // 2. Load the settings
        let settings = Settings.main
        
        // 3. Assert they are default values
        XCTAssertNotNil(settings)
//        XCTAssertEqual(settings!.panelPosition, Settings.default.panelPosition)
//        XCTAssertEqual(settings!.pasteboardChangeCount, Settings.default.pasteboardChangeCount)
        XCTAssertEqual(settings!, Settings.default)
    }

    func testPersistentStorage() {
        // 1. Given settings
        var settings = Settings.main
        
        // 2. Set some things
        settings?.panelPosition = .bottom
        settings?.pasteboardChangeCount = 42
        Settings.main = settings
        // Retrieve the settings again
        settings = Settings.main
        
        // 3. Check they have been saved
        XCTAssertEqual(settings?.panelPosition, .bottom)
        XCTAssertEqual(settings?.pasteboardChangeCount, 42)
    }
    
    func testObserving() {
        // 1. Given fresh settings
        XCTAssertEqual(Settings.main.panelPosition, Settings.default.panelPosition)
        XCTAssertEqual(Settings.main.pasteboardChangeCount, Settings.default.pasteboardChangeCount)
        let disposeBag = DisposeBag()
        
        // 2. Bind settings to behaviour relays
        let panelPosition = BehaviorRelay<PanelPosition>(value: .right)
        Settings.main.bindPanelPositionTo(state: panelPosition).disposed(by: disposeBag)
        panelPosition.accept(.bottom)
        
        let pasteboardChangeCount = BehaviorRelay<Int>(value: -1)
        Settings.main.bindPasteboardChangeCountTo(state: pasteboardChangeCount.asObservable()).disposed(by: disposeBag)
        pasteboardChangeCount.accept(42)
        
        // 3. Check that the settings have been saved
        XCTAssertEqual(Settings.main.panelPosition, .bottom)
        XCTAssertEqual(Settings.main.pasteboardChangeCount, 42)
    }
    
    func testDecodesSettingsSavedBeforeIgnoredApps() throws {
        // 1. Settings as saved by a version without `ignoredAppBundleIds`
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings.default)) as! [String: Any]
        json.removeValue(forKey: "ignoredAppBundleIds")
        let old = try JSONSerialization.data(withJSONObject: json)
        
        // 2. Decode
        let settings = try JSONDecoder().decode(Settings.self, from: old)
        
        // 3. Nothing else is lost and no apps are ignored
        XCTAssertEqual(settings, Settings.default)
        XCTAssertEqual(settings.ignoredAppBundleIds, [])
    }
    
    func testIgnoredAppsPersist() {
        let disposeBag = DisposeBag()
        let ignored = BehaviorRelay<[String]>(value: [])
        Settings.main.bindIgnoredAppBundleIdsTo(state: ignored.asObservable()).disposed(by: disposeBag)
        
        ignored.accept(["com.example.passwords"])
        
        XCTAssertEqual(Settings.main.ignoredAppBundleIds, ["com.example.passwords"])
    }
    
    func testAddIgnoredAppSkipsDuplicates() {
        XCTAssertEqual(IgnoredAppsSettingsViewController.add(bundleIds: ["b", "a", "c"], to: ["a"]), ["a", "b", "c"])
        XCTAssertNil(IgnoredAppsSettingsViewController.add(bundleIds: ["a"], to: ["a"]))
    }
    
    func testDecodesSettingsSavedBeforeHistorySettings() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings.default)) as! [String: Any]
        for key in ["maxItemAgeDays", "expiringAppBundleIds", "recognizesTextInImages"] {
            json.removeValue(forKey: key)
        }
        let old = try JSONSerialization.data(withJSONObject: json)
        
        let settings = try JSONDecoder().decode(Settings.self, from: old)
        
        XCTAssertEqual(settings, Settings.default)
        XCTAssertEqual(settings.maxItemAgeDays, 0)
        XCTAssertFalse(settings.recognizesTextInImages)
    }
}
