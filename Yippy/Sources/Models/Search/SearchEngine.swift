//
//  SearchEngine.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/9/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation

/// Fuzzy searches the plain text, name and image text of history items off the main thread, filtered by kind and source app (see `SearchQuery`).
///
/// Each item's folded text and kind are read once and cached by item id, so searching again after the history changes only reads the new items.
/// Starting a search supersedes any search still running: it stops early and its completion is never called.
public class SearchEngine {
    
    private let queue = DispatchQueue(label: "MatthewDavidson.Yippy.SearchEngine", qos: .userInitiated)
    
    /// Folded plain text by item id, or nil for items without plain text. Only accessed on `queue`.
    private var texts = [UUID: String?]()
    
    /// Item kinds by id. Only accessed on `queue`.
    private var kinds = [UUID: ItemKind]()
    
    /// Folded text read from item images, by id. Only accessed on `queue`.
    private var recognizedTexts = [UUID: String]()
    
    /// Bumped by every search and cancel. Guarded by `lock`, since running searches read it to stop early.
    private var generation = 0
    private let lock = NSLock()
    
    private func nextGeneration() -> Int {
        lock.lock()
        defer { lock.unlock() }
        generation += 1
        return generation
    }
    
    private func isCurrent(_ g: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return g == generation
    }
    
    /// Searches `items` for `query`.
    ///
    /// - Parameter completion: Called on the main queue with the matching items in their original order, unless another search or `cancel()` comes first.
    ///
    /// Call on the main thread, which is where item metadata and app names are read.
    func search(query: String, in items: [HistoryItem], completion: @escaping ([HistoryItem]) -> Void) {
        let g = nextGeneration()
        let query = SearchQuery(query)
        let needle = foldForSearch(query.text)
        // Metadata is changed on the main thread, so take a copy for the search queue
        let metadataList = items.map({ $0.metadata })
        var appNames = [String: String]()
        if !query.apps.isEmpty {
            for id in Set(metadataList.compactMap({ $0.sourceBundleId })) {
                appNames[id] = AppInfo.name(forBundleId: id)
            }
        }
        
        queue.async {
            var matches = [HistoryItem]()
            for (item, metadata) in zip(items, metadataList) {
                guard self.isCurrent(g) else {
                    return
                }
                if self.matches(item, metadata: metadata, query: query, needle: needle, appNames: appNames) {
                    matches.append(item)
                }
            }
            
            // Forget items that are no longer in the history
            let ids = Set(items.map({ $0.fsId }))
            self.texts = self.texts.filter({ ids.contains($0.key) })
            self.kinds = self.kinds.filter({ ids.contains($0.key) })
            self.recognizedTexts = self.recognizedTexts.filter({ ids.contains($0.key) })
            
            DispatchQueue.main.async {
                if self.isCurrent(g) {
                    completion(matches)
                }
            }
        }
    }
    
    /// Stops any running search from completing.
    func cancel() {
        _ = nextGeneration()
    }
    
    private func matches(_ item: HistoryItem, metadata: HistoryItemMetadata, query: SearchQuery, needle: String, appNames: [String: String]) -> Bool {
        if !query.kinds.isEmpty && !query.kinds.contains(kind(of: item)) {
            return false
        }
        if !query.matchesApp(name: metadata.sourceBundleId.flatMap({ appNames[$0] }), bundleId: metadata.sourceBundleId) {
            return false
        }
        if needle.isEmpty {
            return true
        }
        if let text = text(for: item), isSubsequence(needle, of: text) {
            return true
        }
        if let title = metadata.title, isSubsequence(needle, of: foldForSearch(title)) {
            return true
        }
        if let text = recognizedText(for: item, metadata: metadata), isSubsequence(needle, of: text) {
            return true
        }
        return false
    }
    
    private func kind(of item: HistoryItem) -> ItemKind {
        if let kind = kinds[item.fsId] {
            return kind
        }
        let kind = ItemKind.of(types: item.types, plainText: item.getPlainString())
        kinds[item.fsId] = kind
        return kind
    }
    
    /// The folded text read from the item's image. It's only read once, so once it's there it never changes.
    private func recognizedText(for item: HistoryItem, metadata: HistoryItemMetadata) -> String? {
        if let text = recognizedTexts[item.fsId] {
            return text
        }
        guard let text = metadata.recognizedText, !text.isEmpty else {
            return nil
        }
        let folded = foldForSearch(text)
        recognizedTexts[item.fsId] = folded
        return folded
    }
    
    private func text(for item: HistoryItem) -> String? {
        if let text = texts[item.fsId] {
            return text
        }
        let text = item.getPlainString().map(foldForSearch)
        texts[item.fsId] = text
        return text
    }
}
