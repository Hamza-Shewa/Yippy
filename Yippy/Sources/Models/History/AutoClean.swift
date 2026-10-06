//
//  AutoClean.swift
//  Yippy
//

import Foundation

/// Decides which clipboard history items have expired, for the History settings tab's automatic deletion.
///
/// Favourites are never cleaned.
struct AutoClean {

    /// Items older than this many days are deleted. 0 keeps them forever.
    var maxAgeDays: Int

    /// Items copied from these apps are deleted once they are `expiringItemLifetime` old.
    var expiringBundleIds: Set<String>

    /// How long items copied from one of the `expiringBundleIds` are kept.
    static let expiringItemLifetime: TimeInterval = 60

    /// The choices offered for `maxAgeDays`, in menu order.
    static let maxAgeDaysOptions: [(title: String, days: Int)] = [
        ("Never", 0),
        ("After 1 day", 1),
        ("After 1 week", 7),
        ("After 1 month", 30),
        ("After 3 months", 90),
    ]

    /// Whether anything can expire at all.
    var isActive: Bool {
        return maxAgeDays > 0 || !expiringBundleIds.isEmpty
    }

    /// Whether an item with this metadata should be deleted at `now`. Items with no copy date never expire.
    func isExpired(_ metadata: HistoryItemMetadata, now: Date = Date()) -> Bool {
        guard let copiedAt = metadata.copiedAt else {
            return false
        }
        let age = now.timeIntervalSince(copiedAt)
        if maxAgeDays > 0 && age >= TimeInterval(maxAgeDays) * 24 * 60 * 60 {
            return true
        }
        if let source = metadata.sourceBundleId, expiringBundleIds.contains(source), age >= Self.expiringItemLifetime {
            return true
        }
        return false
    }
}
