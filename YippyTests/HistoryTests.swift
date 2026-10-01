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
    
    // MARK: - Duplicates
    
    func testCopyingTopItemAgainAddsNothing() {
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        XCTAssertEqual(historyStrings(), ["a"])
    }
    
    func testCopyingOlderItemMovesItToTop() {
        for str in ["a", "b", "c"] {
            copy(str)
            history.pasteboardDidChange(pasteboard, originBundleId: nil)
        }
        let a = history.items[2]
        
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        XCTAssertEqual(historyStrings(), ["a", "c", "b"])
        // The same item, not a new copy of it
        XCTAssertTrue(history.items[0] === a)
    }
    
    func testCopyingOlderItemLoadedFromDiskMovesItToTop() {
        // Items loaded from disk have no unsaved data, so their content comes through the cache
        let historyFM = HistoryFileManagerMock()
        let cache = HistoryCache(historyFM: historyFM)
        let id = UUID()
        historyFM.data[id] = [.string: "saved".data(using: .utf8)!]
        let saved = HistoryItem(fsId: id, types: [.string], cache: cache)
        history = History(historyFM: historyFM, cache: cache, items: [HistoryItem(unsavedData: [.string: "top".data(using: .utf8)!], cache: cache), saved])
        
        copy("saved")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        XCTAssertEqual(history.items.count, 2)
        XCTAssertTrue(history.items[0] === saved)
    }
    
    func testSameTextWithDifferentTypesIsNewItem() {
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        // Same string, plus rich text
        pasteboard.declareTypes([.string, .rtf], owner: nil)
        pasteboard.setString("a", forType: .string)
        pasteboard.setData("{\\rtf1 a}".data(using: .utf8)!, forType: .rtf)
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        XCTAssertEqual(history.items.count, 2)
        // The new item keeps every type, including the string it shares with the old top item
        XCTAssertTrue(Set(history.items[0].types).isSuperset(of: [.string, .rtf]))
        XCTAssertEqual(history.items[0].getPlainString(), "a")
    }
    
    func testCopyingDeletedItemAddsItAgain() {
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        history.deleteItem(at: 0)
        
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        XCTAssertEqual(historyStrings(), ["a"])
    }
}
