//
//  YippyHistoryTests.swift
//  YippyTests
//

import XCTest
@testable import Yippy

/// Tests for `YippyHistory`, the panel's view of the history, which may be a filtered search result.
class YippyHistoryTests: XCTestCase {
    
    var cache: HistoryCache!
    var history: History!
    var pasteboard: NSPasteboard!
    
    // History order: a, b, c, d
    var a: HistoryItem!
    var b: HistoryItem!
    var c: HistoryItem!
    var d: HistoryItem!
    
    override func setUp() {
        // Never synthesize a real ⌘V from a unit test
        Helper.keyPressHelper = KeyPressHelperMock()
        
        cache = HistoryCache()
        a = item("a")
        b = item("b")
        c = item("c")
        d = item("d")
        history = History(historyFM: HistoryFileManagerMock(), cache: cache, items: [a, b, c, d])
        pasteboard = NSPasteboard(name: NSPasteboard.Name(rawValue: "YippyHistoryTests"))
    }
    
    override func tearDown() {
        pasteboard.releaseGlobally()
        Helper.keyPressHelper = KeyPressHelper()
    }
    
    func item(_ str: String) -> HistoryItem {
        return HistoryItem(unsavedData: [.string: str.data(using: .utf8)!], cache: cache)
    }
    
    func historyStrings() -> [String?] {
        return history.items.map({ $0.getPlainString() })
    }
    
    // MARK: - paste(selected:)
    
    func testPasteOutOfRangeDoesNothing() {
        // ⌘9 with only four items used to crash in History.moveItem(at:to:)
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard)
        
        yippyHistory.paste(selected: 9)
        
        XCTAssertEqual(historyStrings(), ["a", "b", "c", "d"])
    }
    
    func testPasteFromSearchResultsPastesTheShownItem() {
        // Search results show b, d
        let yippyHistory = YippyHistory(history: history, items: [b, d], pasteboard: pasteboard)
        
        yippyHistory.paste(selected: 1)
        
        XCTAssertEqual(historyStrings(), ["d", "a", "b", "c"])
        XCTAssertEqual(pasteboard.string(forType: .string), "d")
    }
    
    // MARK: - delete(selected:)
    
    func testDeleteFromSearchResultsDeletesTheShownItem() {
        let yippyHistory = YippyHistory(history: history, items: [b, d], pasteboard: pasteboard)
        
        let next = yippyHistory.delete(selected: 1)
        
        XCTAssertEqual(historyStrings(), ["a", "b", "c"])
        XCTAssertEqual(next, 0)
    }
    
    func testDeleteOutOfRangeDoesNothing() {
        let yippyHistory = YippyHistory(history: history, items: [b, d], pasteboard: pasteboard)
        
        XCTAssertNil(yippyHistory.delete(selected: 2))
        XCTAssertEqual(historyStrings(), ["a", "b", "c", "d"])
    }
    
    func testDeleteItemNoLongerInHistoryDoesNothing() {
        // The shown results can be stale for a moment after the history changes
        let yippyHistory = YippyHistory(history: history, items: [b, d], pasteboard: pasteboard)
        history.deleteItem(at: 1)
        
        XCTAssertNil(yippyHistory.delete(selected: 0))
        XCTAssertEqual(historyStrings(), ["a", "c", "d"])
    }
    
    // MARK: - move(from:to:)
    
    func testMoveUpInSearchResults() {
        let yippyHistory = YippyHistory(history: history, items: [b, d], pasteboard: pasteboard)
        
        yippyHistory.move(from: 1, to: 0)
        
        XCTAssertEqual(historyStrings(), ["a", "d", "b", "c"])
    }
    
    func testMoveDownInSearchResults() {
        let yippyHistory = YippyHistory(history: history, items: [a, c], pasteboard: pasteboard)
        
        yippyHistory.move(from: 0, to: 1)
        
        XCTAssertEqual(historyStrings(), ["b", "c", "a", "d"])
    }
    
    func testMoveToTopWritesPasteboard() {
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard)
        
        yippyHistory.move(from: 2, to: 0)
        
        XCTAssertEqual(historyStrings(), ["c", "a", "b", "d"])
        XCTAssertEqual(pasteboard.string(forType: .string), "c")
    }
}
