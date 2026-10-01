//
//  HistoryFileManagerMock.swift
//  YippyTests
//
//  Created by Matthew Davidson on 21/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class HistoryFileManagerMock: HistoryFileManager {
    
    var dataCallCount = 0
    var data = [UUID: [NSPasteboard.PasteboardType: Data]]()
    
    override func loadData(forItemWithId id: UUID, andType type: NSPasteboard.PasteboardType) -> Data? {
        dataCallCount += 1
        if let d = data[id]?[type] {
            return d
        }
        return nil
    }
    
    // Keep history mutations in memory only.
    override func insertItem(newHistory: [HistoryItem], at i: Int, completionHandler handler: ((Bool) -> Void)? = nil) {}
    override func deleteItem(newHistory: [HistoryItem], deleted: HistoryItem, completionHandler handler: ((Bool) -> Void)? = nil) {}
    override func moveItem(newHistory: [HistoryItem], from: Int, to: Int, completionHandler: ((Bool) -> Void)? = nil) {}
    override func reduce(oldHistory: [HistoryItem], toSize size: Int, completionHandler handler: ((Bool) -> Void)? = nil) {}
    override func clearHistory(completionHandler handler: ((Bool) -> Void)? = nil) {}
}
