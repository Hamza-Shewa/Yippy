//
//  YippyTableViewDelegate.swift
//  Yippy
//
//  Created by Matthew Davidson on 27/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

protocol YippyTableViewDelegate {
    
    func yippyTableView(_ yippyTableView: YippyTableView, selectedDidChange selected: Int?)
    
    func yippyTableView(_ yippyTableView: YippyTableView, didMoveItem from: Int, to: Int)

    /// Whether the item is one of the favourites, for the heart on its row.
    func yippyTableView(_ yippyTableView: YippyTableView, isFavourite item: HistoryItem) -> Bool

    /// The heart on the item's row, or the menu item, was clicked.
    func yippyTableView(_ yippyTableView: YippyTableView, didToggleFavouriteOf item: HistoryItem)

    /// The item's context menu asked for it to be pasted.
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestPasteOf item: HistoryItem, plainText: Bool)

    /// The item's context menu asked for this text to be pasted instead of the item (transformed, or read from its image).
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestPasteOf item: HistoryItem, text: String)

    /// Whether the item can be renamed and edited (favourites only).
    func yippyTableView(_ yippyTableView: YippyTableView, canEdit item: HistoryItem) -> Bool

    /// The item's context menu asked to rename it.
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestRenameOf item: HistoryItem)

    /// The item's context menu asked to edit its text.
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestEditOf item: HistoryItem)

    /// The item's context menu asked to show only the items copied from this app.
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestItemsFromApp bundleId: String)
}
