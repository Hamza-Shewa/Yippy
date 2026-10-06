//
//  State.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxRelay
import RxSwift
import LoginServiceKit

class State {
    
    // MARK: - Singleton
    static var main = State()
    
    
    // MARK: - Attributes
    // RxSwift
    var isHistoryPanelShown: BehaviorRelay<Bool>
    
    var panelPosition: BehaviorRelay<PanelPosition>
    
    var currentScreen: BehaviorRelay<NSScreen>
    
    var previewHistoryItem: BehaviorRelay<HistoryItem?>
    
    var launchAtLogin: BehaviorRelay<Bool>
    
    var showsRichText: BehaviorRelay<Bool>
    
    var pastesRichText: BehaviorRelay<Bool>
    
    /// Bundle ids of apps whose copies are not saved to the history.
    var ignoredAppBundleIds: BehaviorRelay<[String]>
    
    /// Clipboard history items older than this many days are deleted. 0 keeps them forever.
    var maxItemAgeDays: BehaviorRelay<Int>
    
    /// Bundle ids of apps whose copies are deleted after a minute.
    var expiringAppBundleIds: BehaviorRelay<[String]>
    
    /// Whether the text in copied images is read so search can find it.
    var recognizesTextInImages: BehaviorRelay<Bool>
    
    var disposeBag: DisposeBag
    
    // History
    var historyCache: HistoryCache!
    var history: History!
    
    // Favourites, stored separately from the history (see `HistoryFileManager.favourites`)
    var favouritesCache: HistoryCache!
    var favourites: History!
    
    /// Monitors the pasteboard, here it can be controlled in the future if needed.
    var pasteboardMonitor: PasteboardMonitor!
    
    /// Reads the text in copied images while `recognizesTextInImages` is on.
    var textRecognizer = TextRecognizer()
    
    
    // MARK: - Constructor
    init(settings: Settings = Settings.main, disposeBag: DisposeBag = DisposeBag()) {
        // Setup RxSwift attributes
        self.isHistoryPanelShown = BehaviorRelay<Bool>(value: false)
        self.panelPosition = BehaviorRelay<PanelPosition>(value: settings.panelPosition)
        self.previewHistoryItem = BehaviorRelay<HistoryItem?>(value: nil)
        self.launchAtLogin = BehaviorRelay<Bool>(value: LoginServiceKit.isExistLoginItems())
        self.showsRichText = BehaviorRelay<Bool>(value: settings.showsRichText)
        self.pastesRichText = BehaviorRelay<Bool>(value: settings.pastesRichText)
        self.ignoredAppBundleIds = BehaviorRelay<[String]>(value: settings.ignoredAppBundleIds)
        self.maxItemAgeDays = BehaviorRelay<Int>(value: settings.maxItemAgeDays)
        self.expiringAppBundleIds = BehaviorRelay<[String]>(value: settings.expiringAppBundleIds)
        self.recognizesTextInImages = BehaviorRelay<Bool>(value: settings.recognizesTextInImages)
        self.currentScreen = BehaviorRelay<NSScreen>(value: Self.getCurrentScreen(forMouseLocation: NSEvent.mouseLocation))
        self.disposeBag = disposeBag
        
        // Setup history
        self.historyCache = HistoryCache()
        self.history = History.load(cache: historyCache)
        self.history.recordPasteboardChange(withCount: settings.pasteboardChangeCount)
        self.history.setMaxItems(settings.maxHistory)
        
        // Setup favourites
        try? HistoryFileManager.favourites.checkHistoryDirectory()
        self.favouritesCache = HistoryCache(historyFM: .favourites)
        self.favourites = History.load(historyFM: .favourites, cache: favouritesCache)
        self.favourites.setMaxItems(Int.max)
        
        // Bind settings to state
        Self.bind(settings: settings, toState: self, disposeBag: disposeBag)
        
        // Setup pasteboard monitor
        self.pasteboardMonitor = PasteboardMonitor(pasteboard: NSPasteboard.general, changeCount: settings.pasteboardChangeCount, delegate: self.history)
        
        Self.monitorPastesRichText(state: self)
        Self.monitorIgnoredApps(state: self)
        Self.monitorAutoClean(state: self)
        Self.monitorTextRecognition(state: self)
        Self.monitorMousePosition(state: self)
    }
    
    // MARK: - Constructor Helpers
    
    static func bind(settings: Settings, toState state: State, disposeBag: DisposeBag) {
        settings.bindPasteboardChangeCountTo(state: state.history!.observableLastRecordedChangeCount).disposed(by: disposeBag)
        settings.bindPanelPositionTo(state: state.panelPosition).disposed(by: disposeBag)
        settings.bindMaxHistoryTo(state: state.history.maxItems).disposed(by: disposeBag)
        settings.bindShowsRichTextTo(state: state.showsRichText.asObservable()).disposed(by: disposeBag)
        settings.bindPastesRichTextTo(state: state.pastesRichText.asObservable()).disposed(by: disposeBag)
        settings.bindIgnoredAppBundleIdsTo(state: state.ignoredAppBundleIds.asObservable()).disposed(by: disposeBag)
        settings.bindMaxItemAgeDaysTo(state: state.maxItemAgeDays.asObservable()).disposed(by: disposeBag)
        settings.bindExpiringAppBundleIdsTo(state: state.expiringAppBundleIds.asObservable()).disposed(by: disposeBag)
        settings.bindRecognizesTextInImagesTo(state: state.recognizesTextInImages.asObservable()).disposed(by: disposeBag)
    }
    
    static func monitorPastesRichText(state: State) {
        state.pastesRichText.distinctUntilChanged().subscribe(onNext: {
            HistoryItem.pastesRichText = $0
        }).disposed(by: state.disposeBag)
    }
    
    static func monitorIgnoredApps(state: State) {
        state.ignoredAppBundleIds.subscribe(onNext: {
            state.history.ignoredBundleIds = Set($0)
        }).disposed(by: state.disposeBag)
    }
    
    /// Deletes expired clipboard history items when the settings change and every few seconds after.
    static func monitorAutoClean(state: State) {
        Observable.combineLatest(state.maxItemAgeDays, state.expiringAppBundleIds).subscribe(onNext: { _ in
            state.cleanHistory()
        }).disposed(by: state.disposeBag)
        
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { (_) in
            state.cleanHistory()
        }
    }
    
    /// Deletes the clipboard history items `AutoClean` says have expired.
    func cleanHistory(now: Date = Date()) {
        let autoClean = AutoClean(maxAgeDays: maxItemAgeDays.value, expiringBundleIds: Set(expiringAppBundleIds.value))
        guard autoClean.isActive else {
            return
        }
        // The top item is what's on the clipboard, unless something has been copied since that the history ignored
        let topIsOnPasteboard = NSPasteboard.general.changeCount == history.lastRecordedChangeCount
        let top = history.items.first
        let deleted = history.deleteItems(where: { autoClean.isExpired($0.metadata, now: now) })
        if topIsOnPasteboard, let top = top, deleted.contains(where: { $0 === top }) {
            // Don't leave it on the clipboard either. The pasteboard also can't fulfil its promise for the deleted item.
            history.recordPasteboardChange(withCount: NSPasteboard.general.clearContents())
        }
    }
    
    /// Reads the text in images while the setting is on: all unread ones when it's turned on, then each new one.
    static func monitorTextRecognition(state: State) {
        state.recognizesTextInImages.distinctUntilChanged().subscribe(onNext: {
            state.textRecognizer.isEnabled = $0 && TextRecognizer.isAvailable
            state.textRecognizer.enqueue(state.history.items, in: state.history)
            state.textRecognizer.enqueue(state.favourites.items, in: state.favourites)
        }).disposed(by: state.disposeBag)
        
        for history in [state.history!, state.favourites!] {
            history.subscribe(onNext: { items, change in
                if case .insert(let i) = change {
                    state.textRecognizer.enqueue([items[i]], in: history)
                }
            })
        }
    }
    
    static func monitorMousePosition(state: State) {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (_) in
            let currentScreen = getCurrentScreen(forMouseLocation: NSEvent.mouseLocation)
            if currentScreen != state.currentScreen.value {
                state.currentScreen.accept(currentScreen)
            }
        }
    }
    
    static func getCurrentScreen(forMouseLocation location: NSPoint) -> NSScreen {
        for screen in NSScreen.screens {
            if screen.frame.contains(location) {
                return screen
            }
        }
        return NSScreen.main!
    }
}
