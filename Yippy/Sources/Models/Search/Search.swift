//
//  Search.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/9/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

// Adapted from: https://github.com/khoi/fuzzy-swift/blob/master/Sources/Fuzzy/Fuzzy.swift
public func performSearch(needle: String, haystack: String) -> Bool {
    return isSubsequence(foldForSearch(needle), of: foldForSearch(haystack))
}

/// Normalises text so a plain `Character` comparison is case insensitive.
///
/// Fold each string once and reuse it, rather than comparing character by character with `localizedCaseInsensitiveCompare`, which creates two strings per character.
func foldForSearch(_ str: String) -> String {
    return str.folding(options: .caseInsensitive, locale: .current)
}

/// Whether the characters of `needle` appear in `haystack` in order (not necessarily next to each other). Both should already be folded.
func isSubsequence(_ needle: String, of haystack: String) -> Bool {
    var haystackIterator = haystack.makeIterator()
    for n in needle {
        var found = false
        while let h = haystackIterator.next() {
            if h == n {
                found = true
                break
            }
        }
        if !found {
            return false
        }
    }
    return true
}

/// What kind of thing an item is, for the search bar's type filters.
enum ItemKind: CaseIterable {
    case text
    case link
    case image
    case file
    case color
    
    /// The filter words that select this kind, like "/img".
    var filterWords: [String] {
        switch self {
        case .text: return ["text"]
        case .link: return ["link", "url"]
        case .image: return ["img", "image"]
        case .file: return ["file"]
        case .color: return ["color", "colour"]
        }
    }
    
    /// The kind of an item with these types and plain text. Text that is nothing but a web link counts as a link.
    static func of(types: [NSPasteboard.PasteboardType], plainText: String?) -> ItemKind {
        if types.contains(.fileURL) {
            return .file
        }
        if types.contains(.tiff) || types.contains(.png) {
            return .image
        }
        if types.contains(.color) {
            return .color
        }
        if types.contains(.URL) {
            return .link
        }
        if let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines), isLink(text) {
            return .link
        }
        return .text
    }
    
    private static func isLink(_ text: String) -> Bool {
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }),
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) else {
            return false
        }
        return match.range.length == (text as NSString).length
    }
}

/// A search bar query: words to find, plus "/img"-style type filters and "@app" source filters.
///
/// Items must be one of the filtered kinds (if any), copied from one of the filtered apps (if any), and contain the text.
struct SearchQuery: Equatable {
    
    /// The words that aren't filters, as typed.
    var text: String
    var kinds: Set<ItemKind>
    /// Folded app names (without spaces) to match the source app's name or bundle id against.
    var apps: [String]
    
    init(_ query: String) {
        var words = [String]()
        var kinds = Set<ItemKind>()
        var apps = [String]()
        for word in query.split(separator: " ").map(String.init) {
            if word.count > 1, word.hasPrefix("/"),
               let kind = ItemKind.allCases.first(where: { $0.filterWords.contains(word.dropFirst().lowercased()) }) {
                kinds.insert(kind)
            }
            else if word.count > 1, word.hasPrefix("@") {
                apps.append(foldForSearch(String(word.dropFirst())))
            }
            else {
                words.append(word)
            }
        }
        self.text = words.joined(separator: " ")
        self.kinds = kinds
        self.apps = apps
    }
    
    /// Whether an app with this name and bundle id passes the app filters.
    func matchesApp(name: String?, bundleId: String?) -> Bool {
        if apps.isEmpty {
            return true
        }
        let candidates = [name, bundleId].compactMap({ $0 }).map({ foldForSearch($0).filter({ !$0.isWhitespace }) })
        return apps.contains(where: { app in candidates.contains(where: { $0.contains(app) }) })
    }
    
    /// The text to put in the search bar to show only items copied from this app.
    static func appFilter(forAppName name: String) -> String {
        return "@" + name.filter({ !$0.isWhitespace })
    }
}
