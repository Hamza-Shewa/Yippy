//
//  FavouritesTests.swift
//  YippyTests
//

import XCTest
@testable import Yippy

class FavouritesTests: XCTestCase {
    
    var cache: HistoryCache!
    var favourites: History!
    
    override func setUp() {
        cache = HistoryCache()
        favourites = History(historyFM: HistoryFileManagerMock(), cache: cache, items: [])
    }
    
    func item(_ str: String) -> HistoryItem {
        return HistoryItem(unsavedData: [.string: str.data(using: .utf8)!], cache: HistoryCache())
    }
    
    func testToggleAddsCopyToTop() {
        let a = item("a")
        XCTAssertTrue(favourites.toggleFavourite(a))
        XCTAssertTrue(favourites.toggleFavourite(item("b")))
        
        XCTAssertEqual(favourites.items.map({ $0.getPlainString() }), ["b", "a"])
        // A copy with its own id, so deleting it from the clipboard history doesn't affect it
        XCTAssertFalse(favourites.items[1] === a)
        XCTAssertNotEqual(favourites.items[1].fsId, a.fsId)
    }
    
    func testToggleSameContentRemoves() {
        favourites.toggleFavourite(item("a"))
        favourites.toggleFavourite(item("b"))
        
        // A different item with the same content
        XCTAssertFalse(favourites.toggleFavourite(item("a")))
        XCTAssertEqual(favourites.items.map({ $0.getPlainString() }), ["b"])
    }
    
    func testDifferentTypesAreDifferentFavourites() {
        favourites.toggleFavourite(item("a"))
        let rich = HistoryItem(unsavedData: [.string: "a".data(using: .utf8)!, .rtf: "{\\rtf1 a}".data(using: .utf8)!], cache: HistoryCache())
        
        XCTAssertTrue(favourites.toggleFavourite(rich))
        XCTAssertEqual(favourites.items.count, 2)
    }
    
    func testFavouritesAreNotTrimmed() {
        // State sets this so the clipboard history limit doesn't apply
        favourites.setMaxItems(Int.max)
        for i in 0..<20 {
            favourites.toggleFavourite(item("\(i)"))
        }
        XCTAssertEqual(favourites.items.count, 20)
    }
    
    // MARK: - Storage
    
    func testFavouritesStoredInOwnDirectory() {
        let fm = HistoryFileManager.favourites
        XCTAssertEqual(fm.directory, Constants.urls.favourites)
        XCTAssertNotEqual(fm.directory, Constants.urls.history)
        let id = UUID()
        XCTAssertEqual(fm.getUrl(forItemWithId: id), Constants.urls.favourites.appendingPathComponent(id.uuidString, isDirectory: true))
    }
    
    func testLoadedHistoryUsesItsFileManager() {
        // loadHistory used to build the History with the default (clipboard) file manager
        let orderManager = ArrayFileManagerMock(url: URL(fileURLWithPath: "/tmp/favourites/order.xml"))
        orderManager.shouldReadSucceed = true
        orderManager.order = [] as NSArray
        let fileManager = FileManagerMock()
        let directory = URL(fileURLWithPath: "/tmp/favourites", isDirectory: true)
        fileManager.directoryContents[directory] = []
        let fm = HistoryFileManager(fileManager: fileManager, orderManager: orderManager, dataFileManager: DataFileManagerMock(), dispatchQueue: .main, errorLogger: ErrorLoggerMock(), warningLogger: WarningLoggerMock(), alerter: AlerterMock(), directory: directory)
        
        let loaded = fm.loadHistory(cache: cache)
        
        XCTAssertTrue(loaded.historyFM === fm)
    }
}
