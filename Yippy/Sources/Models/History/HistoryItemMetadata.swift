//
//  HistoryItemMetadata.swift
//  Yippy
//

import Foundation
import Cocoa

/// What Yippy knows about an item besides its pasteboard data.
///
/// Saved for every item of a history in one `metadata.plist` next to its `order.xml` (see `HistoryFileManager.saveMetadata`).
/// Items saved by older versions have none, so every field is optional.
struct HistoryItemMetadata: Codable, Equatable {

    /// Bundle id of the app that was in front when the item was copied.
    var sourceBundleId: String?

    /// When the item was last copied.
    var copiedAt: Date?

    /// A name the user gave the item (favourites only).
    var title: String?

    /// Text read out of the item's image, or "" if none was found. Nil if the image hasn't been read.
    var recognizedText: String?

    init(sourceBundleId: String? = nil, copiedAt: Date? = nil, title: String? = nil, recognizedText: String? = nil) {
        self.sourceBundleId = sourceBundleId
        self.copiedAt = copiedAt
        self.title = title
        self.recognizedText = recognizedText
    }

    /// A short description of how long ago `date` was, like "5 min ago".
    static func timeAgo(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minute = 60.0, hour = 60 * minute, day = 24 * hour
        if seconds < minute {
            return "just now"
        }
        if seconds < hour {
            return "\(Int(seconds / minute)) min ago"
        }
        if seconds < day {
            return "\(Int(seconds / hour)) hr ago"
        }
        if seconds < 7 * day {
            let days = Int(seconds / day)
            return days == 1 ? "yesterday" : "\(days) days ago"
        }
        return dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return formatter
    }()
}

/// Names and icons of apps by bundle id, for showing where items were copied from.
///
/// Looking an app up goes to Launch Services, so both are cached. Main thread only.
enum AppInfo {

    private static var names = [String: String]()
    private static var icons = [String: NSImage?]()

    /// The app's display name, or the bundle id if it isn't installed.
    static func name(forBundleId bundleId: String) -> String {
        if let name = names[bundleId] {
            return name
        }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
            .map({ FileManager.default.displayName(atPath: $0.path) })
            .map({ $0.hasSuffix(".app") ? String($0.dropLast(4)) : $0 })
            ?? bundleId
        names[bundleId] = name
        return name
    }

    /// The app's icon, or nil if it isn't installed.
    static func icon(forBundleId bundleId: String) -> NSImage? {
        if let icon = icons[bundleId] {
            return icon
        }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
            .map({ NSWorkspace.shared.icon(forFile: $0.path) })
        icons[bundleId] = icon
        return icon
    }
}
