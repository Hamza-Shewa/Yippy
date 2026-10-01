//
//  SearchEngineTests.swift
//  YippyTests
//

import XCTest
@testable import Yippy

class SearchEngineTests: XCTestCase {
    
    var cache: HistoryCache!
    
    override func setUp() {
        cache = HistoryCache()
    }
    
    func item(_ str: String) -> HistoryItem {
        return HistoryItem(unsavedData: [.string: str.data(using: .utf8)!], cache: cache)
    }
    
    func search(_ engine: SearchEngine, _ query: String, in items: [HistoryItem]) -> [String?] {
        var found = [String?]()
        let done = expectation(description: "Search finished")
        engine.search(query: query, in: items) { matches in
            found = matches.map({ $0.getPlainString() })
            done.fulfill()
        }
        waitForExpectations(timeout: 5)
        return found
    }
    
    // MARK: - performSearch()
    
    func testPerformSearch() {
        XCTAssertTrue(performSearch(needle: "hlo", haystack: "hello"))
        XCTAssertTrue(performSearch(needle: "HeLLo", haystack: "hello world"))
        XCTAssertTrue(performSearch(needle: "", haystack: "hello"))
        XCTAssertTrue(performSearch(needle: "é", haystack: "CAFÉ"))
        XCTAssertFalse(performSearch(needle: "olh", haystack: "hello"))
        XCTAssertFalse(performSearch(needle: "helloo", haystack: "hello"))
    }
    
    // MARK: - search(query:in:completion:)
    
    func testSearchReturnsMatchesInOrder() {
        let items = [item("Apple pie"), item("banana"), item("pineapple"), item("APPLES")]
        XCTAssertEqual(search(SearchEngine(), "apple", in: items), ["Apple pie", "pineapple", "APPLES"])
    }
    
    func testSearchSkipsItemsWithoutText() {
        // An image-only item between text items used to shift every later search result by one
        let image = HistoryItem(unsavedData: [.tiff: Data([0, 1, 2])], cache: cache)
        let items = [item("a"), image, item("needle"), item("d")]
        XCTAssertEqual(search(SearchEngine(), "needle", in: items), ["needle"])
    }
    
    func testSearchSeesNewItems() {
        let engine = SearchEngine()
        var items = [item("one"), item("two")]
        XCTAssertEqual(search(engine, "o", in: items), ["one", "two"])
        
        items.insert(item("four"), at: 0)
        items.remove(at: 2)
        XCTAssertEqual(search(engine, "o", in: items), ["four", "one"])
    }
    
    func testNewerSearchSupersedesOlder() {
        let engine = SearchEngine()
        let items = (0..<2000).map({ item(String(repeating: "lorem ipsum ", count: 100) + "\($0)") })
        
        let older = expectation(description: "Older search completed")
        older.isInverted = true
        engine.search(query: "lorem", in: items) { _ in older.fulfill() }
        
        let newer = expectation(description: "Newer search completed")
        engine.search(query: "1999", in: items) { matches in
            XCTAssertEqual(matches.count, 1)
            newer.fulfill()
        }
        wait(for: [older, newer], timeout: 5)
    }
    
    func testCancelStopsCompletion() {
        let engine = SearchEngine()
        let e = expectation(description: "Search completed")
        e.isInverted = true
        engine.search(query: "a", in: [item("a")]) { _ in e.fulfill() }
        engine.cancel()
        waitForExpectations(timeout: 0.5)
    }
    
    func testCompletionOnMainThread() {
        let e = expectation(description: "Search completed")
        SearchEngine().search(query: "a", in: [item("a")]) { _ in
            XCTAssertTrue(Thread.isMainThread)
            e.fulfill()
        }
        waitForExpectations(timeout: 2)
    }
    
    // MARK: - Performance
    
    /// 1000 items of about 2 KB each, searching for something that is in none of them.
    func testPerformanceSearch() {
        let lorem = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 35)
        let items = (0..<1000).map({ item("\(lorem) \($0)") })
        let engine = SearchEngine()
        
        measure {
            _ = search(engine, "zzz", in: items)
        }
    }
}
