//
//  History+Favourites.swift
//  Yippy
//

import Foundation
import Cocoa

extension History {
    
    /// Index of the item with the same types and data as `item`, if there is one.
    func indexOfItem(withSameContentAs item: HistoryItem) -> Int? {
        guard let data = item.allDataIfComplete() else {
            return nil
        }
        let types = Set(data.keys)
        return items.firstIndex(where: { Set($0.types) == types && $0.allDataIfComplete() == data })
    }
    
    /// Adds a copy of `item` to the top of this history, or removes the copy if it's already here.
    ///
    /// Used on the favourites, which keep their own copy of the data so clearing or trimming the clipboard history doesn't affect them.
    ///
    /// - Returns: Whether the item is now in this history.
    @discardableResult
    func toggleFavourite(_ item: HistoryItem) -> Bool {
        if let i = indexOfItem(withSameContentAs: item) {
            deleteItem(at: i)
            return false
        }
        guard let data = item.allDataIfComplete() else {
            return false
        }
        insertItem(HistoryItem(unsavedData: data, cache: cache), at: 0)
        return true
    }
}

extension HistoryItem {
    
    /// All the item's data, or nil if any of it can't be read.
    func allDataIfComplete() -> [NSPasteboard.PasteboardType: Data]? {
        var data = [NSPasteboard.PasteboardType: Data]()
        for type in types {
            guard let d = self.data(forType: type) else {
                return nil
            }
            data[type] = d
        }
        return data
    }
}
