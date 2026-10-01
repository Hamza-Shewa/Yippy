//
//  YippyHotKeys.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

struct YippyHotKeys {
    
    static var toggle = YippyHotKey(key: .v, modifiers: [.command, .shift])
    static var `return` = YippyHotKey(key: .return, modifiers: [])
    static var escape = YippyHotKey(key: .escape, modifiers: [])
    static var downArrow = YippyHotKey(key: .downArrow, modifiers: [])
    static var upArrow = YippyHotKey(key: .upArrow, modifiers: [])
    static var leftArrow = YippyHotKey(key: .leftArrow, modifiers: [])
    static var rightArrow = YippyHotKey(key: .rightArrow, modifiers: [])
    static var pageDown = YippyHotKey(key: .pageDown, modifiers: [])
    static var pageUp = YippyHotKey(key: .pageUp, modifiers: [])
    static var ctrlAltCmdLeftArrow = YippyHotKey(key: .leftArrow, modifiers: [.control, .option, .command])
    static var ctrlAltCmdRightArrow = YippyHotKey(key: .rightArrow, modifiers: [.control, .option, .command])
    static var ctrlAltCmdDownArrow = YippyHotKey(key: .downArrow, modifiers: [.control, .option, .command])
    static var ctrlAltCmdUpArrow = YippyHotKey(key: .upArrow, modifiers: [.control, .option, .command])
    static var ctrlDelete = YippyHotKey(key: .delete, modifiers: [.control])
    static var ctrlSpace = YippyHotKey(key: .space, modifiers: [.control])
    static var cmdBackslash = YippyHotKey(key: .backslash, modifiers: [.command])
    
    static var cmd0 = YippyHotKey(key: .zero, modifiers: [.command])
    static var cmd1 = YippyHotKey(key: .one, modifiers: [.command])
    static var cmd2 = YippyHotKey(key: .two, modifiers: [.command])
    static var cmd3 = YippyHotKey(key: .three, modifiers: [.command])
    static var cmd4 = YippyHotKey(key: .four, modifiers: [.command])
    static var cmd5 = YippyHotKey(key: .five, modifiers: [.command])
    static var cmd6 = YippyHotKey(key: .six, modifiers: [.command])
    static var cmd7 = YippyHotKey(key: .seven, modifiers: [.command])
    static var cmd8 = YippyHotKey(key: .eight, modifiers: [.command])
    static var cmd9 = YippyHotKey(key: .nine, modifiers: [.command])
    
    /// Keys that only act inside the history panel.
    ///
    /// Hot keys are registered system-wide, so `YippyViewController` pauses all of these while the panel is hidden. A new in-panel key must be added here, or it will take that key away from every other app.
    static var inPanel: [YippyHotKey] {
        return [
            `return`, escape, downArrow, upArrow, pageDown, pageUp,
            ctrlAltCmdLeftArrow, ctrlAltCmdRightArrow, ctrlAltCmdDownArrow, ctrlAltCmdUpArrow,
            ctrlDelete, ctrlSpace, cmdBackslash,
            cmd0, cmd1, cmd2, cmd3, cmd4, cmd5, cmd6, cmd7, cmd8, cmd9,
        ]
    }
}
