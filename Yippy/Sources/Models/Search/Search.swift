//
//  Search.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/9/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation

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
