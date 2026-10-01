//
//  YippyUITests.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 26/7/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
import HotKey

class YippyUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUp() {
        // Nothing to clean up after a failure
        continueAfterFailure = false
        
        // Set full access control
        AccessControlMock.setControlGranted(true)
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SRCROOT"] = ProcessInfo.processInfo.environment["SRCROOT"]
    }
    
    /// Opens the panel with the toggle hot key while another app is frontmost.
    ///
    /// Yippy only synthesizes ⌘V once it is no longer the active app, and on close it re-activates whichever app was frontmost when the panel opened. `app.typeKey` activates Yippy first, so send the hot key to Finder instead.
    func pressHotKeyFromOtherApp() {
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        finder.typeKey("v", modifierFlags: [.command, .shift])
        // Right after launch the hot key is occasionally missed, so try once more
        if !app.yippyWindow.waitForExistence(timeout: 2) {
            finder.activate()
            finder.typeKey("v", modifierFlags: [.command, .shift])
        }
        XCTAssertTrue(app.yippyWindow.waitForExistence(timeout: 2))
    }
    
    /// Search results arrive asynchronously, so wait for the table to settle.
    func waitForItemCount(_ count: Int) {
        let predicate = NSPredicate(format: "count == %d", count)
        let e = expectation(for: predicate, evaluatedWith: app.yippyTableViewItems)
        wait(for: [e], timeout: 3)
    }
    
    func assertCmdV() {
        // The paste is synthesized asynchronously once Yippy is no longer active, so poll for it.
        var keyPress = KeyPressMock.handleKeyPress()
        let deadline = Date().addingTimeInterval(3)
        while keyPress == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            keyPress = KeyPressMock.handleKeyPress()
        }
        // Assert there was a key press
        XCTAssertNotNil(keyPress)
        // Assert it was a c + cmd key press
        let (keyCode, flags) = keyPress!
        XCTAssertEqual(keyCode, KeyPressMock.constants.cKeyCode)
        XCTAssertEqual(flags, KeyPressMock.constants.enterEventFlags)
        // Assert there was just a single key press
        XCTAssertNil(KeyPressMock.handleKeyPress())
    }
    
    func testYippyToggle() {
        // Launch app
        app.launch()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.exists)
        
        // Toggle window
        app.statusItemButton.click()
        app.toggleYippyWindowButton.click()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.exists)
        
        // Toggle window
        app.statusItemButton.click()
        app.toggleYippyWindowButton.click()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.exists)
    }
    
    func testHotKeyToggle() {
        // Launch app
        app.launch()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.isDisplayed)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.isDisplayed)
        
        // Type escape
        app.typeKey(XCUIKeyboardKey.escape)
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
    }
    
    func testYippyWindowPositions() {
        // Launch app
        app.launch()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.exists)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.exists)
        
        // Check window location is .right
        XCTAssertEqual(app.yippyWindow.frame.midX, PanelPosition.right.getFrame(forScreen: NSScreen.main!).midX)
        
        // Change to position left
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionLeftButton.click()
        
        // Check window location is .left
        XCTAssertEqual(app.yippyWindow.frame.midX, PanelPosition.left.getFrame(forScreen: NSScreen.main!).midX)
        
        // Change to position bottom
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionBottomButton.click()
        
        // Check window location is .bottom
        let statusBarHeight = NSScreen.main!.frame.height - NSScreen.main!.visibleFrame.height
        XCTAssertEqual(app.yippyWindow.frame.midY, NSScreen.main!.visibleFrame.height + statusBarHeight - Constants.panel.menuHeight/2)
        
        // Change to position top
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionTopButton.click()
        
        // Check window location is .top
        XCTAssertEqual(app.yippyWindow.frame.midY, Constants.panel.menuHeight/2)
        
        // Change back to position right
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionRightButton.click()
        
        // Check window location is .right
        XCTAssertEqual(app.yippyWindow.frame.midX, PanelPosition.right.getFrame(forScreen: NSScreen.main!).midX)
    }
    
    func testEmptyYippyHistory() {
        // Empty app support directory
        app.launchArguments.append("--test-dir=Empty")
        
        // Test no contents on pasteboard
        NSPasteboard.general.clearContents()
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        
        // Check Yippy window displayed with no cells
        XCTAssertTrue(app.yippyTableView.isDisplayed)
        XCTAssertEqual(app.yippyTableViewItems.count, 0)
        
        // Close Yippy window
        app.pressHotKey()
        
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My first test!", forType: .string)
        
        // Show the Yippy window
        app.pressHotKey()
        
        // Check Yippy window displayed with 1 cell
        XCTAssertTrue(app.yippyTableView.isDisplayed)
        XCTAssertEqual(app.yippyTableViewItems.count, 1)
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "My first test!")
    }
    
    func testLoadFromDefinedSettings() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        
        // Check Yippy window displayed with correct number of cells
        XCTAssertTrue(app.yippyTableView.isDisplayed)
        XCTAssertEqual(app.yippyTableViewItems.count, 5)
    }
    
    func testEnterToPaste() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        pressHotKeyFromOtherApp()
        app.typeKey(.return)
        
        // Assert item was pasted
        assertCmdV()
        
        // Assert the Yippy window is closed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
    }
    
    func testPasteFromHistory() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        pressHotKeyFromOtherApp()
        // Select index 2
        app.getYippyTableViewCell(at: 2).click()
        app.typeKey(.return)
        
        // Assert item was pasted
        assertCmdV()
        
        // Assert the Yippy window is closed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // Assert the pasteboard now contains the index 2 text (index 1 in history)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "2")
        
        // Open Yippy window
        app.pressHotKey()
        
        // Check that the items have been shuffled
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "2")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 1), "My latest copy")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 2), "1")
    }
    
    func testPasteFromShortcut() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        pressHotKeyFromOtherApp()
        // Use short cut for item index 2 (⌘ + 2)
        app.typeKey("2", modifierFlags: .command)
        
        // Assert item was pasted
        assertCmdV()
        
        // Assert the Yippy window is closed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // Assert the pasteboard now contains the index 2 text (index 1 in history)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "2")
        
        // Open Yippy window
        app.pressHotKey()
        
        // Check that the items have been shuffled
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "2")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 1), "My latest copy")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 2), "1")
    }
    
    func testDelete() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        // Select index 2
        app.getYippyTableViewCell(at: 2).click()
        // Delete
        app.typeKey(.delete, modifierFlags: .control)
        
        // Check that the item is gone
        XCTAssertEqual(app.yippyTableViewItems.count, 4)
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "My latest copy")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 1), "1")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 2), "3")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 3), "4")
        
        // Delete again
        app.typeKey(.delete, modifierFlags: .control)
        app.typeKey(.delete, modifierFlags: .control)
        
        // Check that the items are gone
        XCTAssertEqual(app.yippyTableViewItems.count, 2)
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "My latest copy")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 1), "1")
        
        // Delete first item
        app.getYippyTableViewCell(at: 0).click()
        app.typeKey(.delete, modifierFlags: .control)
        
        // Check that the item is gone
        XCTAssertEqual(app.yippyTableViewItems.count, 1)
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "1")
        
        // Delete final item
        app.typeKey(.delete, modifierFlags: .control)
        
        // Check all items gone
        XCTAssertEqual(app.yippyTableViewItems.count, 0)
        
        // Check pasteboard is empty
        XCTAssertTrue(NSPasteboard.general.types?.isEmpty ?? true)
    }
    
    func testShortcutBeyondHistoryDoesNothing() {
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory, 4 items
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        let count = app.yippyTableViewItems.count
        XCTAssertLessThan(count, 9)
        
        // ⌘9 used to crash Yippy when there were fewer than 10 items
        app.typeKey("9", modifierFlags: .command)
        
        // Still running, window still open, nothing pasted or removed
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.yippyWindow.isDisplayed)
        XCTAssertEqual(app.yippyTableViewItems.count, count)
    }
    
    func testDeleteFromSearchResults() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window and search for "3"
        app.pressHotKey()
        let allItems = (0..<app.yippyTableViewItems.count).map({ app.getYippyTableViewItemString(at: $0) })
        XCTAssertTrue(allItems.contains("3"))
        app.typeKey("\\", modifierFlags: .command)
        app.typeText("3")
        waitForItemCount(1)
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "3")
        
        // Delete the only result, which used to delete the first item in the whole history instead
        app.getYippyTableViewCell(at: 0).click()
        app.typeKey(.delete, modifierFlags: .control)
        waitForItemCount(0)
        
        // Clear the search: only "3" is gone
        app.typeKey("\\", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        waitForItemCount(allItems.count - 1)
        let remaining = (0..<app.yippyTableViewItems.count).map({ app.getYippyTableViewItemString(at: $0) })
        XCTAssertEqual(remaining, allItems.filter({ $0 != "3" }))
    }
    
    func testFavourites() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Basic app support directory, which has no favourites
        app.launchArguments.append("--test-dir=A")
        
        // Launch app
        app.launch()
        
        // Open Yippy window and favourite "2" and "3"
        app.pressHotKey()
        let count = app.yippyTableViewItems.count
        app.getYippyTableViewCell(at: 2).click()
        app.typeKey("f", modifierFlags: .control)
        app.getYippyTableViewCell(at: 3).click()
        app.typeKey("f", modifierFlags: .control)
        XCTAssertTrue(app.yippyWindow.checkBoxes["Favourites (2)"].waitForExistence(timeout: 2))
        
        // The favourites tab shows them, newest first
        app.yippyWindow.checkBoxes["Favourites (2)"].click()
        waitForItemCount(2)
        XCTAssertEqual(app.getYippyTableViewItemString(at: 0), "3")
        XCTAssertEqual(app.getYippyTableViewItemString(at: 1), "2")
        let screenshot = XCTAttachment(screenshot: app.yippyWindow.screenshot())
        screenshot.name = "Favourites"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        
        // Deleting a favourite doesn't touch the clipboard history
        app.getYippyTableViewCell(at: 0).click()
        app.typeKey(.delete, modifierFlags: .control)
        waitForItemCount(1)
        XCTAssertTrue(app.yippyWindow.checkBoxes["Favourites (1)"].exists)
        
        app.yippyWindow.checkBoxes["Clipboard"].click()
        waitForItemCount(count)
    }
    
    func testTypes() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Basic app support directory
        app.launchArguments.append("--test-dir=Big")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        
        // Assert the types of items: Text, icon, thumbnail, tiff
        XCTAssertEqual(app.getYippyTableViewCellType(at: 0), Accessibility.identifiers.yippyTextCellView)
        XCTAssertEqual(app.getYippyTableViewCellType(at: 1), Accessibility.identifiers.yippyColorCellView)
        XCTAssertEqual(app.getYippyTableViewCellType(at: 2), Accessibility.identifiers.yippyFileIconCellView)
        XCTAssertEqual(app.getYippyTableViewCellType(at: 4), Accessibility.identifiers.yippyTiffCellView)
    }
}
