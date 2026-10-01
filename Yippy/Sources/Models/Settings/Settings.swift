//
//  Settings.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Default
import RxSwift
import RxRelay
import HotKey

struct Settings: Codable, DefaultStorable {
    
    // MARK: - Singleton
    
    private init(
        panelPosition: PanelPosition,
        pasteboardChangeCount: Int,
        toggleHotKey: KeyCombo,
        maxHistory: Int,
        showsRichText: Bool,
        pastesRichText: Bool,
        ignoredAppBundleIds: [String]
    ) {
        self.panelPosition = panelPosition
        self.pasteboardChangeCount = pasteboardChangeCount
        self.toggleHotKey = toggleHotKey
        self.maxHistory = maxHistory
        self.showsRichText = showsRichText
        self.pastesRichText = pastesRichText
        self.ignoredAppBundleIds = ignoredAppBundleIds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.panelPosition = try container.decode(PanelPosition.self, forKey: .panelPosition)
        self.pasteboardChangeCount = try container.decode(Int.self, forKey: .pasteboardChangeCount)
        self.toggleHotKey = try container.decode(KeyCombo.self, forKey: .toggleHotKey)
        self.maxHistory = try container.decode(Int.self, forKey: .maxHistory)
        self.showsRichText = try container.decode(Bool.self, forKey: .showsRichText)
        self.pastesRichText = try container.decode(Bool.self, forKey: .pastesRichText)
        // Added after release, so settings saved by older versions don't have it.
        self.ignoredAppBundleIds = try container.decodeIfPresent([String].self, forKey: .ignoredAppBundleIds) ?? []
    }
    
    static var main: Settings! {
        get {
            let settings = Settings.read(forKey: "settings")
            if settings != nil {
                return settings
            }
            return Settings.default
        }
        set (main) {
            main.write(withKey: "settings")
        }
    }
    
    // MARK: - Default
    
    static let `default` = Settings(
        panelPosition: .right,
        pasteboardChangeCount: -1,
        toggleHotKey: KeyCombo(key: .v, modifiers: [.command, .shift]),
        maxHistory: Constants.settings.maxHistoryItemsDefault,
        showsRichText: true,
        pastesRichText: true,
        ignoredAppBundleIds: []
    )
    
    // MARK: - Settings
    
    var panelPosition: PanelPosition
    
    var pasteboardChangeCount: Int
    
    var toggleHotKey: KeyCombo
    
    var maxHistory: Int
    
    var showsRichText: Bool
    
    var pastesRichText: Bool
    
    /// Bundle ids of apps whose copies are not saved to the history.
    var ignoredAppBundleIds: [String]
    
    
    // MARK: - State Binding Methods
    
    func bindPanelPositionTo(state: BehaviorRelay<PanelPosition>) -> Disposable {
        return state.bind { (x) in
            Settings.main.panelPosition = x
        }
    }
    
    func bindPasteboardChangeCountTo(state: Observable<Int>) -> Disposable {
        return state.bind { (x) in
            Settings.main.pasteboardChangeCount = x
        }
    }
    
    func bindMaxHistoryTo(state: Observable<Int>) -> Disposable {
        return state.bind { (x) in
            Settings.main.maxHistory = x
        }
    }
    
    func bindShowsRichTextTo(state: Observable<Bool>) -> Disposable {
        return state.bind { (x) in
            Settings.main.showsRichText = x
        }
    }
    
    func bindPastesRichTextTo(state: Observable<Bool>) -> Disposable {
        return state.bind { (x) in
            Settings.main.pastesRichText = x
        }
    }
    
    func bindIgnoredAppBundleIdsTo(state: Observable<[String]>) -> Disposable {
        return state.bind { (x) in
            Settings.main.ignoredAppBundleIds = x
        }
    }
}

extension Settings {
    
    struct testData {
        static var a: Settings {
            var settings = Settings.default
            settings.panelPosition = .left
            return settings
        }
        
        static var ignoredApps: Settings {
            var settings = Settings.default
            settings.ignoredAppBundleIds = ["com.apple.TextEdit", "com.example.notInstalled"]
            return settings
        }
        
        static func from(_ str: String) -> Settings? {
            switch str {
            case "--Settings.testData=a":
                return a
            case "--Settings.testData=ignoredApps":
                return ignoredApps
            default:
                return nil
            }
        }
    }
}

extension Settings: Equatable {
    
}
