//
//  TextTransform.swift
//  Yippy
//

import Foundation

/// Changes made to an item's text when it is pasted from the right-click menu's "Paste Transformed" submenu.
enum TextTransform: CaseIterable {
    case trimWhitespace
    case uppercase
    case lowercase
    case titleCase
    case removeLinkTracking
    case prettyPrintJSON

    var title: String {
        switch self {
        case .trimWhitespace: return "Trim Whitespace"
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        case .titleCase: return "Title Case"
        case .removeLinkTracking: return "Remove Tracking from Links"
        case .prettyPrintJSON: return "Pretty-Print JSON"
        }
    }

    /// The transformed text, or nil if this transform doesn't apply to it (e.g. it isn't JSON).
    func apply(to text: String) -> String? {
        switch self {
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .titleCase:
            return text.capitalized
        case .removeLinkTracking:
            return Self.removingLinkTracking(from: text)
        case .prettyPrintJSON:
            return Self.prettyPrintedJSON(text)
        }
    }

    // MARK: - Links

    /// Query parameters that only exist to track where a link was shared or clicked.
    static let trackingParameters: Set<String> = [
        "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "yclid", "twclid", "ttclid", "igshid", "li_fat_id",
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "mkt_tok", "oly_anon_id", "oly_enc_id", "vero_id", "wickedid",
        "ref_src", "ref_url", "s_cid",
    ]

    static func isTrackingParameter(_ name: String) -> Bool {
        let name = name.lowercased()
        return name.hasPrefix("utm_") || trackingParameters.contains(name)
    }

    /// The text with tracking parameters removed from every web link in it.
    static func removingLinkTracking(from text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return text
        }
        let result = NSMutableString(string: text)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: result.length))
        // Replace from the end so earlier ranges stay valid
        for match in matches.reversed() {
            let original = result.substring(with: match.range)
            guard let cleaned = removingTrackingParameters(fromLink: original) else {
                continue
            }
            result.replaceCharacters(in: match.range, with: cleaned)
        }
        return result as String
    }

    /// The link without its tracking parameters, or nil if it isn't a web link or has none.
    static func removingTrackingParameters(fromLink link: String) -> String? {
        guard var components = URLComponents(string: link),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let queryItems = components.percentEncodedQueryItems else {
            return nil
        }
        let kept = queryItems.filter({ !isTrackingParameter($0.name) })
        if kept.count == queryItems.count {
            return nil
        }
        // The percent-encoded items keep the rest of the link exactly as it was
        components.percentEncodedQueryItems = kept.isEmpty ? nil : kept
        return components.string
    }

    // MARK: - JSON

    /// The text as indented JSON with sorted keys, or nil if it isn't a JSON object or array.
    static func prettyPrintedJSON(_ text: String) -> String? {
        guard let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              JSONSerialization.isValidJSONObject(object) else {
            return nil
        }
        var options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        if #available(OSX 10.15, *) {
            options.insert(.withoutEscapingSlashes)
        }
        guard let pretty = try? JSONSerialization.data(withJSONObject: object, options: options) else {
            return nil
        }
        return String(data: pretty, encoding: .utf8)
    }
}
