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
    
    /// Whether this history has an item with the same types and data as `item`.
    ///
    /// Unlike `indexOfItem(withSameContentAs:)` this remembers a hash of each item's data, so it is cheap enough to ask for every row the panel draws.
    func containsItem(withSameContentAs item: HistoryItem) -> Bool {
        guard let contentHash = Self.contentHash(of: item) else {
            return false
        }
        return items.contains(where: { Self.contentHash(of: $0) == contentHash })
    }

    /// Hashes of item contents by item id. Item ids are unique across histories, so one cache serves them all.
    private static var contentHashes = [UUID: Int]()

    private static func contentHash(of item: HistoryItem) -> Int? {
        if let hash = contentHashes[item.fsId] {
            return hash
        }
        guard let data = item.allDataIfComplete() else {
            return nil
        }
        var hasher = Hasher()
        for type in data.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let bytes = data[type]!
            hasher.combine(type)
            hasher.combine(bytes.count)
            // Hash every byte. `Data`'s own hash only looks at a prefix of them.
            bytes.withUnsafeBytes({ hasher.combine(bytes: $0) })
        }
        let hash = hasher.finalize()
        if contentHashes.count > 5000 {
            contentHashes.removeAll()
        }
        contentHashes[item.fsId] = hash
        return hash
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
