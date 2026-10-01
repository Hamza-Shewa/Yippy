//
//  HistoryTests.swift
//  YippyTests
//

import XCTest
@testable import Yippy

/// Tests for `History` reacting to pasteboard changes.
class HistoryTests: XCTestCase {
    
    var cache: HistoryCache!
    var history: History!
    var pasteboard: NSPasteboard!
    
    override func setUp() {
        cache = HistoryCache()
        history = History(historyFM: HistoryFileManagerMock(), cache: cache, items: [])
        pasteboard = NSPasteboard(name: NSPasteboard.Name(rawValue: "HistoryTests"))
    }
    
    override func tearDown() {
        pasteboard.releaseGlobally()
    }
    
    func copy(_ str: String) {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(str, forType: .string)
    }
    
    func historyStrings() -> [String?] {
        return history.items.map({ $0.getPlainString() })
    }
    
    // MARK: - Ignored apps
    
    func testCopyFromIgnoredAppIsNotSaved() {
        history.ignoredBundleIds = ["com.example.passwords"]
        
        copy("secret")
        history.pasteboardDidChange(pasteboard, originBundleId: "com.example.passwords")
        
        XCTAssertEqual(historyStrings(), [])
        // The change is still consumed, so it isn't picked up later
        XCTAssertEqual(history.lastRecordedChangeCount, pasteboard.changeCount)
    }
    
    func testCopyFromOtherAppIsSaved() {
        history.ignoredBundleIds = ["com.example.passwords"]
        
        copy("hello")
        history.pasteboardDidChange(pasteboard, originBundleId: "com.example.editor")
        copy("world")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        XCTAssertEqual(historyStrings(), ["world", "hello"])
    }
}
