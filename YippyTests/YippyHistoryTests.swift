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
    
    func testPasteFromFavouritesKeepsOrder() {
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard, movesPastedItemToTop: false)
        
        yippyHistory.paste(selected: 2)
        
        XCTAssertEqual(historyStrings(), ["a", "b", "c", "d"])
        XCTAssertEqual(pasteboard.string(forType: .string), "c")
    }
    
    func testPastePlainTextDropsTheStyling() {
        let styled = HistoryItem(unsavedData: [.string: "styled".data(using: .utf8)!, .rtf: "{\\rtf1\\ansi {\\b styled}}".data(using: .utf8)!], cache: cache)
        history.insertItem(styled, at: 0)
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard)
        
        yippyHistory.paste(selected: 0, plainText: true)
        
        XCTAssertEqual(pasteboard.string(forType: .string), "styled")
        XCTAssertNil(pasteboard.data(forType: .rtf))
    }
    
    func testPastePlainTextMovesItemToTopLikeAPaste() {
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard)
        
        yippyHistory.paste(selected: 2, plainText: true)
        
        XCTAssertEqual(historyStrings(), ["c", "a", "b", "d"])
        XCTAssertEqual(pasteboard.string(forType: .string), "c")
    }
    
    func testPastePlainTextUsesTheTextOfRtfWhenThereIsNoPlainString() {
        let rtfOnly = HistoryItem(unsavedData: [.rtf: "{\\rtf1\\ansi hello}".data(using: .utf8)!], cache: cache)
        history.insertItem(rtfOnly, at: 0)
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard)
        
        yippyHistory.paste(selected: 0, plainText: true)
        
        XCTAssertEqual(pasteboard.string(forType: .string), "hello")
        XCTAssertNil(pasteboard.data(forType: .rtf))
    }
    
    func testPastePlainTextWithoutTextPastesTheItemAsItIs() {
        let png = Data([1, 2, 3])
        let image = HistoryItem(unsavedData: [.png: png], cache: cache)
        history.insertItem(image, at: 0)
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard)
        
        yippyHistory.paste(selected: 0, plainText: true)
        
        XCTAssertEqual(pasteboard.data(forType: .png), png)
        XCTAssertNil(pasteboard.string(forType: .string))
    }
    
    // MARK: - delete(selected:)
    
    func testDeleteTopOfClipboardClearsPasteboard() {
        // The top item is what's on the pasteboard, and its data is about to go
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("a", forType: .string)
        
        _ = yippyHistory.delete(selected: 0)
        
        XCTAssertNil(pasteboard.string(forType: .string))
    }
    
    func testDeleteFirstFavouriteKeepsPasteboard() {
        // Unfavouriting the first favourite must not wipe whatever was copied
        let yippyHistory = YippyHistory(history: history, items: history.items, pasteboard: pasteboard, movesPastedItemToTop: false)
        pasteboard.clearContents()
        pasteboard.setString("copied", forType: .string)
        
        _ = yippyHistory.delete(selected: 0)
        
        XCTAssertEqual(historyStrings(), ["b", "c", "d"])
        XCTAssertEqual(pasteboard.string(forType: .string), "copied")
    }
    
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
