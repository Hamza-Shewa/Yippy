# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Yippy is a macOS menu-bar clipboard manager (Swift 5, AppKit, RxSwift, CocoaPods; deployment target 10.13/10.14). It only builds and runs on macOS with Xcode. There is no linter or formatter configured.

## Build, run, test

Always open/build `Yippy.xcworkspace` (not the `.xcodeproj`). Dependencies come from two places: CocoaPods (`Default`, `LoginServiceKit` from a git URL, `RxSwift`/`RxCocoa`, plus `RxBlocking`/`RxTest` for tests) and Swift Package Manager (`HotKey`, from the `mattDavo/HotKey` fork, pinned in `Yippy.xcworkspace/xcshareddata/swiftpm/Package.resolved`). `Pods/` is committed, so `pod install` is only needed when the `Podfile` changes.

There are three shared schemes, each with its own build configuration and bundle id:

| Scheme | Config | Bundle id | Use |
| --- | --- | --- | --- |
| `Yippy` | Debug/Release | `MatthewDavidson.Yippy` | production run/archive |
| `Yippy Beta` | Beta Debug/Beta Release (`BETA` flag, different status-bar icon) | `MatthewDavidson.YippyBeta` | day-to-day development, beta archive |
| `Yippy XCTest` | `XCTest` (`DEBUG XCTEST` flags) | `MatthewDavidson.YippyXCTest` | the only scheme that runs tests |

```sh
xcodebuild -workspace Yippy.xcworkspace -scheme "Yippy Beta" build

# all unit tests / one class / one test
xcodebuild test -workspace Yippy.xcworkspace -scheme "Yippy XCTest" -only-testing:YippyTests
xcodebuild test -workspace Yippy.xcworkspace -scheme "Yippy XCTest" -only-testing:YippyTests/HistoryCacheTests
xcodebuild test -workspace Yippy.xcworkspace -scheme "Yippy XCTest" -only-testing:YippyTests/HistoryCacheTests/testDataWhenFMReturnsNil
```

`YippyUITests` drives the real app via XCUITest and needs the test runner to have Accessibility permission. The scheme's launch environment sets `SRCROOT`, and the UI tests forward it to the app (see "UI-test hooks" below). `./create-installer.sh <AppName>` builds a `.dmg` from an `<AppName>.app` placed next to it and needs `create-dmg` installed.

Because the app-support directory and `UserDefaults` are keyed by bundle id, Yippy, Yippy Beta and the XCTest build each have separate history and settings.

## Architecture

### Singletons and wiring
`AppDelegate` creates `Controller.main = Controller(state: State.main, settings: Settings.main)`. `Controller` owns the status item/menu and the window controllers (history panel, preview, and lazily the welcome/help/about/settings windows). Code reaches `State.main`, `Settings.main` and `Controller.main` globally instead of through injection; only the history/model layer takes injected dependencies (which is what the unit tests mock).

`State` is the hub: RxSwift `BehaviorRelay`s for UI state (`isHistoryPanelShown`, `panelPosition`, `currentScreen`, `previewHistoryItem`, `showsRichText`, `pastesRichText`) plus the `History`, `HistoryCache` and `PasteboardMonitor`. Windows and menu items subscribe to these relays, so e.g. toggling the panel is just `isHistoryPanelShown.accept(...)`. `State.bind` mirrors relay values back into `Settings.main` (a `Codable` struct persisted to `UserDefaults` through the `Default` pod), which is how settings persist: there are no explicit "save settings" calls for those fields. `Settings.main` reads and writes `UserDefaults` on every access.

### Clipboard capture → history → disk
1. `PasteboardMonitor` polls `NSPasteboard.changeCount` every 50 ms and calls `History.pasteboardDidChange`.
2. `History` drops items carrying denylisted types (password managers, `org.nspasteboard.ConcealedType`, etc.), skips types whose data matches the current top item, and otherwise inserts a `HistoryItem(unsavedData:)` at index 0.
3. `History` mutates its in-memory array synchronously, notifies subscribers (a closure list via `History.subscribe` with a `History.Change` enum, not Rx), then calls `HistoryFileManager`, which does all disk work on one serial background queue.
4. On disk: `~/Library/Application Support/<bundle id>/history/<item UUID>/<pasteboard type raw value>` (one file per type) plus `history/order.xml`, an array of UUID strings that defines item order. `HistoryFileManager.loadHistory` reconciles the folders against the order file and alerts on mismatches. Errors/warnings also go to `error.log`/`warning.log` in the same directory via `ErrorLogger`/`WarningLogger`.
5. `HistoryItem` loads data lazily through `HistoryCache` (LRU, 100 MB). Items must be registered with the cache before `data(withId:forType:)` serves them from it; `unsavedData` holds the bytes until the file is written, then `startCaching()` drops them.

### Pasting
`YippyHistory.paste` moves the item to the top, clears the pasteboard and immediately calls `history.recordPasteboardChange(withCount:)` so `History` ignores the change Yippy itself made. It then writes the item (`HistoryItem` is an `NSPasteboardWriting` using `.promised`, so data is only read when requested) and polls until Yippy is no longer the active app before synthesizing ⌘V with `Helper.pressCommandV()`. That needs the Accessibility permission, which is why the Welcome window exists. `YippyWindowController` restores the previously frontmost app when the panel closes.

### Panel UI and key handling
`Main.storyboard` instantiates `YippyWindowController` (an `NSPanel` subclass, `YippyWindow`). Its frame is driven by `combineLatest(panelPosition, currentScreen)` through `PanelPosition.getFrame`; `State` polls the mouse every 0.1 s to update `currentScreen`. `YippyViewController` combines `results` (full history or search results) and `selected` relays and renders them in `YippyTableView` in `onAllChange`.

Keyboard handling has two separate systems:
- `YippyHotKey` wraps the `HotKey` package (system-wide hotkeys, with long-press repeat). The global toggle (default ⌘⇧V, stored in `Settings.toggleHotKey`) and the in-panel keys (arrows, Page Up/Down, Return, Esc, ⌘0–9 quick paste, ⌃Delete, ⌃Space preview, ⌘\ focus search, ⌃⌥⌘+arrows to move the panel) are all registered as system-wide hotkeys. Each in-panel key is paused whenever the panel is hidden by an explicit `bindHotKeyToYippyWindow(...)` call in `YippyViewController.viewDidLoad`, so a new in-panel shortcut needs its own binding or it will steal that key system-wide (⌘\ is currently not bound this way).
- `KeyPressMonitor` (`NSEvent` monitors) is used only by `HotKeySettingsViewController` to record a new toggle shortcut.

### Search
`SearchEngine` runs a case-insensitive subsequence fuzzy match (`performSearch`) over each item's plain-text string and caches results per query. Hazard: `YippyViewController.updateSearchEngine` builds the index with `compactMap(getPlainString)`, but `runSearch` uses the returned indices directly into `State.main.history.items`, so the two drift apart if any item has no plain-text representation (e.g. image-only items).

### UI-test hooks (compiled into the app)
Launching with `--uitesting` makes `AppDelegate` call `UITesting.setupUITestEnvironment`, which swaps `Helper.accessControlHelper` and `Helper.keyPressHelper` for mocks that exchange state with the test process through named pasteboards (`Yippy.UITesting.*`), and blanks `UserDefaults`. Extra launch args: `--Settings.testData=a` loads canned settings, and `--test-dir=<name>` replaces the app-support directory with a copy of `TestData/<name>` (it deletes the existing one, and needs `SRCROOT`). `Constants/Accessibility.swift` identifiers are compiled into both the app and `YippyUITests`, so changing one means both sides see it.

## Tests
Unit tests mock every system dependency (`FileManagerMock`, `ArrayFileManagerMock`, `DataFileManagerMock`, loggers, `Alerter`) and inject them through the initializers of `HistoryFileManager` and `HistoryCache`; follow that style rather than touching the real file system. `YippyTests.swift` is just Xcode's placeholder.

`PasteboardMonitorTests`' delegate mock still implements `pasteboardDidChange(_:)` without the `originBundleId:` parameter that `PasteboardMonitorDelegate` has required since the password-manager denylist commit, so it does not conform to the protocol. Fix it before expecting the `YippyTests` target to compile.
