//
//  Updater.swift
//  Yippy
//

import Foundation
import Sparkle

/// Automatic updates through Sparkle.
///
/// Sparkle needs an appcast URL (`SUFeedURL`) and the EdDSA public key that release archives are signed with (`SUPublicEDKey`) in Info.plist.
/// Until both are filled in, the updater isn't started and the "Check for Updates..." menu item is hidden, so builds without them behave as before.
class Updater {
    
    static let feedUrlKey = "SUFeedURL"
    static let publicKeyKey = "SUPublicEDKey"
    
    private let controller: SPUStandardUpdaterController?
    
    var isEnabled: Bool {
        return controller != nil
    }
    
    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        #if XCTEST
        // Never check for updates from tests
        controller = nil
        #else
        if Self.isConfigured(infoDictionary: infoDictionary) {
            controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
        else {
            controller = nil
        }
        #endif
    }
    
    static func isConfigured(infoDictionary: [String: Any]?) -> Bool {
        guard let feed = infoDictionary?[feedUrlKey] as? String,
            let key = infoDictionary?[publicKeyKey] as? String else {
            return false
        }
        return URL(string: feed)?.scheme == "https" && !key.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    @objc func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
