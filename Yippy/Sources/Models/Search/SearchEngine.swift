//
//  SearchEngine.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/9/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation

/// Fuzzy searches the plain text of history items off the main thread.
///
/// Each item's folded text is read once and cached by item id, so searching again after the history changes only reads the new items.
/// Starting a search supersedes any search still running: it stops early and its completion is never called.
public class SearchEngine {
    
    private let queue = DispatchQueue(label: "MatthewDavidson.Yippy.SearchEngine", qos: .userInitiated)
    
    /// Folded plain text by item id, or nil for items without plain text. Only accessed on `queue`.
    private var texts = [UUID: String?]()
    
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
    func search(query: String, in items: [HistoryItem], completion: @escaping ([HistoryItem]) -> Void) {
        let g = nextGeneration()
        let needle = foldForSearch(query)
        
        queue.async {
            var matches = [HistoryItem]()
            for item in items {
                guard self.isCurrent(g) else {
                    return
                }
                if let text = self.text(for: item), isSubsequence(needle, of: text) {
                    matches.append(item)
                }
            }
            
            // Forget items that are no longer in the history
            let ids = Set(items.map({ $0.fsId }))
            self.texts = self.texts.filter({ ids.contains($0.key) })
            
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
    
    private func text(for item: HistoryItem) -> String? {
        if let text = texts[item.fsId] {
            return text
        }
        let text = item.getPlainString().map(foldForSearch)
        texts[item.fsId] = text
        return text
    }
}
