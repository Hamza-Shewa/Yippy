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
    
    // MARK: - Metadata
    
    func testCopyRecordsSourceAppAndTime() {
        let before = Date()
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: "com.example.editor")
        
        let metadata = history.items[0].metadata
        XCTAssertEqual(metadata.sourceBundleId, "com.example.editor")
        XCTAssertNotNil(metadata.copiedAt)
        XCTAssertGreaterThanOrEqual(metadata.copiedAt!, before)
    }
    
    func testCopyingOlderItemAgainUpdatesSourceAndTime() {
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: "com.example.first")
        history.updateMetadata(ofItemAt: 0) { $0.copiedAt = Date(timeIntervalSince1970: 0) }
        copy("b")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: "com.example.second")
        
        XCTAssertEqual(historyStrings(), ["a", "b"])
        XCTAssertEqual(history.items[0].metadata.sourceBundleId, "com.example.second")
        XCTAssertGreaterThan(history.items[0].metadata.copiedAt!, Date(timeIntervalSince1970: 0))
    }
    
    func testMetadataIsSavedForEveryItem() {
        let historyFM = HistoryFileManagerMock()
        history = History(historyFM: historyFM, cache: cache, items: [])
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: "com.example.editor")
        history.updateMetadata(ofItemAt: 0) { $0.title = "Name" }
        
        let id = history.items[0].fsId.uuidString
        XCTAssertEqual(historyFM.savedMetadata?.keys.sorted(), [id])
        XCTAssertEqual(historyFM.savedMetadata?[id]?.title, "Name")
        XCTAssertEqual(historyFM.savedMetadata?[id]?.sourceBundleId, "com.example.editor")
        
        history.deleteItem(at: 0)
        XCTAssertEqual(historyFM.savedMetadata?.isEmpty, true)
    }
    
    func testUpdateMetadataNotifiesSubscribers() {
        copy("a")
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
        var updated: Int?
        history.subscribe(onNext: { _, change in
            if case .update(let i) = change {
                updated = i
            }
        })
        
        history.updateMetadata(ofItemWithId: history.items[0].fsId) { $0.title = "Name" }
        
        XCTAssertEqual(updated, 0)
    }
    
    func testReplaceItemKeepsPlaceAndMetadata() {
        for str in ["a", "b"] {
            copy(str)
            history.pasteboardDidChange(pasteboard, originBundleId: "com.example.editor")
        }
        history.updateMetadata(ofItemAt: 1) { $0.title = "Name" }
        let old = history.items[1]
        
        history.replaceItem(at: 1, withData: [.string: "edited".data(using: .utf8)!])
        
        XCTAssertEqual(historyStrings(), ["b", "edited"])
        XCTAssertNotEqual(history.items[1].fsId, old.fsId)
        XCTAssertEqual(history.items[1].metadata, old.metadata)
    }
    
    // MARK: - Auto-clean
    
    func testDeleteItemsWhere() {
        for str in ["a", "b", "c", "d"] {
            copy(str)
            history.pasteboardDidChange(pasteboard, originBundleId: nil)
        }
        
        let deleted = history.deleteItems(where: { ["a", "c"].contains($0.getPlainString()) })
        
        XCTAssertEqual(historyStrings(), ["d", "b"])
        XCTAssertEqual(Set(deleted.map({ $0.getPlainString() })), ["a", "c"])
    }
    
    func testAutoCleanMaxAge() {
        let now = Date()
        let autoClean = AutoClean(maxAgeDays: 7, expiringBundleIds: [])
        XCTAssertTrue(autoClean.isActive)
        XCTAssertFalse(autoClean.isExpired(HistoryItemMetadata(copiedAt: now.addingTimeInterval(-6 * 24 * 60 * 60)), now: now))
        XCTAssertTrue(autoClean.isExpired(HistoryItemMetadata(copiedAt: now.addingTimeInterval(-8 * 24 * 60 * 60)), now: now))
        // Items saved without a date are kept
        XCTAssertFalse(autoClean.isExpired(HistoryItemMetadata(), now: now))
    }
    
    func testAutoCleanExpiringApps() {
        let now = Date()
        let autoClean = AutoClean(maxAgeDays: 0, expiringBundleIds: ["com.example.terminal"])
        XCTAssertTrue(autoClean.isActive)
        XCTAssertFalse(autoClean.isExpired(HistoryItemMetadata(sourceBundleId: "com.example.terminal", copiedAt: now.addingTimeInterval(-30)), now: now))
        XCTAssertTrue(autoClean.isExpired(HistoryItemMetadata(sourceBundleId: "com.example.terminal", copiedAt: now.addingTimeInterval(-61)), now: now))
        XCTAssertFalse(autoClean.isExpired(HistoryItemMetadata(sourceBundleId: "com.example.editor", copiedAt: now.addingTimeInterval(-3600)), now: now))
    }
    
    func testAutoCleanOffByDefault() {
        XCTAssertFalse(AutoClean(maxAgeDays: 0, expiringBundleIds: []).isActive)
    }
}
