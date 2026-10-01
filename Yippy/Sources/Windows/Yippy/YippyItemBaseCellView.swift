//
//  YippyItemBaseCellView.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

/// Abstract base class for all Yippy collection view items.
///
/// Creates and sets up the `contentView`, `shortcutTextView`, `favouriteButton` and the `itemTextView`.
///
/// Handles highlight changes and the right-click menu.
class YippyItemBaseCellView: NSTableCellView {
    
    static let contentViewInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    
    class var identifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("YippyItemBaseCellView")
    }
    
    var contentView: YippyItemContentView!
    var shortcutTextView: YippyItemCellTextView!
    var itemTextView: YippyItemCellTextView!
    var favouriteButton: NSButton!
    
    private var lastSetSelected: Bool?
    
    /// The table and item this cell was last set up for, which the heart and the menu act on.
    private weak var yippyTableView: YippyTableView?
    private var historyItem: HistoryItem?
    
    override func updateLayer() {
        super.updateLayer()
        
        guard let lastSetSelected = self.lastSetSelected else { return }
        if !lastSetSelected { return }
        guard #available(OSX 10.14, *) else { return }
        layer?.backgroundColor = NSColor.controlAccentColor.cgColor
    }
    
    static let shortcutStringAttributes: [NSAttributedString.Key: Any] = [
        .font: Constants.fonts.yippyPlainText,
        .foregroundColor: NSColor.white.withAlphaComponent(0.7)
    ]
    
    func setHighlight(isSelected: Bool) {
        var highlightColor = NSColor.systemBlue.withAlphaComponent(0.7).cgColor
        if #available(OSX 10.14, *) {
            highlightColor = NSColor.controlAccentColor.cgColor
        }
        
        layer?.backgroundColor = isSelected ? highlightColor : NSColor.clear.cgColor
        self.lastSetSelected = isSelected
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    func commonInit() {
        contentView = YippyItemContentView(frame: .zero)
        addSubview(contentView)
        itemTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(itemTextView)
        shortcutTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(shortcutTextView)
        
        wantsLayer = true
        layer?.cornerRadius = 10
        itemTextView.drawsBackground = false
        itemTextView.setAccessibilityIdentifier(Accessibility.identifiers.yippyItemTextView)
        
        setupContentView()
        setupShortcutTextView()
        setupFavouriteButton()
    }
    
    func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 7
        
        addConstraint(NSLayoutConstraint(item: contentView!, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: Self.contentViewInsets.left))
        addConstraint(NSLayoutConstraint(item: contentView!, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: Self.contentViewInsets.top))
        addConstraint(NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: Self.contentViewInsets.right))
        addConstraint(NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: Self.contentViewInsets.bottom))
    }
    
    func setupShortcutTextView() {
        shortcutTextView.translatesAutoresizingMaskIntoConstraints = false
        shortcutTextView.wantsLayer = true
        shortcutTextView.isSelectable = false
        shortcutTextView.textContainer?.lineFragmentPadding = 0
        shortcutTextView.alignment = .right
        shortcutTextView.textContainerInset = NSSize(width: 5, height: 2)
        shortcutTextView.layer?.cornerRadius = 7
        shortcutTextView.layer?.maskedCorners = .layerMinXMaxYCorner
        shortcutTextView.isHorizontallyResizable = false
        shortcutTextView.isVerticallyResizable = false
        shortcutTextView.backgroundColor = NSColor(named: NSColor.Name("ShortcutBackgroundColor"))!
        if #available(OSX 10.14, *) {
            shortcutTextView.backgroundColor = NSColor.controlAccentColor
        }
        shortcutTextView.layer?.zPosition = 1
        
        contentView.addConstraint(NSLayoutConstraint(item: shortcutTextView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 0))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: shortcutTextView, attribute: .trailing, multiplier: 1, constant: 0))
        shortcutTextView.widthAnchor.constraint(equalToConstant: 0, withIdentifier: "width")?.isActive = true
        shortcutTextView.heightAnchor.constraint(equalToConstant: 0, withIdentifier: "height")?.isActive = true
    }
    
    func getShortcutTextViewSize() -> NSSize {
        // Determine the size of the text in one line
        let bRect = shortcutTextView.attributedString().getSingleLineSize()
        return NSSize(width: bRect.width + shortcutTextView.textContainer!.lineFragmentPadding + shortcutTextView.textContainerInset.width * 2, height: bRect.height + shortcutTextView.textContainerInset.height * 2)
    }
    
    func updateShortcutTextViewContraints() {
        let size = getShortcutTextViewSize()
        shortcutTextView.constraint(withIdentifier: "width")?.constant = ceil(size.width)
        shortcutTextView.constraint(withIdentifier: "height")?.constant = ceil(size.height)
    }
    
    func setupShortcutTextView(at i: Int) {
        let shortcutStr = NSAttributedString(string: i < 10 ? "⌘ + \(i)" : "", attributes: Self.shortcutStringAttributes)
        shortcutTextView.attributedText = shortcutStr
        shortcutTextView.isHidden = i >= 10
        updateShortcutTextViewContraints()
    }
    
    // MARK: - Favourite button
    
    /// Creates the heart in the bottom right corner, which sits in the padding to the right of the item's content.
    func setupFavouriteButton() {
        favouriteButton = NSButton(frame: .zero)
        favouriteButton.translatesAutoresizingMaskIntoConstraints = false
        favouriteButton.isBordered = false
        favouriteButton.focusRingType = .none
        favouriteButton.imageScaling = .scaleProportionallyDown
        favouriteButton.target = self
        favouriteButton.action = #selector(favouriteButtonClicked)
        favouriteButton.setAccessibilityIdentifier(Accessibility.identifiers.yippyFavouriteButton)
        favouriteButton.wantsLayer = true
        favouriteButton.layer?.zPosition = 1
        contentView.addSubview(favouriteButton)
        
        NSLayoutConstraint.activate([
            favouriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            favouriteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            favouriteButton.widthAnchor.constraint(equalToConstant: 14),
            favouriteButton.heightAnchor.constraint(equalToConstant: 14),
        ])
        
        setIsFavourite(false)
    }
    
    /// Points the heart and the right-click menu at `historyItem`.
    func setupFavouriteButton(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem) {
        self.yippyTableView = yippyTableView
        self.historyItem = historyItem
        setIsFavourite(yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, isFavourite: historyItem) ?? false)
    }
    
    /// Fills the heart in red for a favourite, otherwise shows it as an outline.
    func setIsFavourite(_ isFavourite: Bool) {
        favouriteButton.toolTip = isFavourite ? "Remove from favourites (⌃F)" : "Add to favourites (⌃F)"
        
        let color = isFavourite ? NSColor.systemRed : NSColor.secondaryLabelColor
        if #available(OSX 11.0, *) {
            favouriteButton.image = NSImage(systemSymbolName: isFavourite ? "heart.fill" : "heart", accessibilityDescription: isFavourite ? "Remove from favourites" : "Add to favourites")
            favouriteButton.imagePosition = .imageOnly
            favouriteButton.contentTintColor = color
        }
        else {
            // SF Symbols need macOS 11, so draw the heart as text
            favouriteButton.image = nil
            favouriteButton.imagePosition = .noImage
            favouriteButton.attributedTitle = NSAttributedString(string: isFavourite ? "♥" : "♡", attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: color,
            ])
        }
    }
    
    /// Subclasses add their content over the whole `contentView` after the heart, so without this the content would take the clicks meant for the heart.
    override func hitTest(_ point: NSPoint) -> NSView? {
        if !favouriteButton.isHidden, favouriteButton.bounds.contains(favouriteButton.convert(point, from: superview)) {
            return favouriteButton
        }
        return super.hitTest(point)
    }
    
    @objc func favouriteButtonClicked() {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didToggleFavouriteOf: historyItem)
    }
    
    // MARK: - Right-click menu
    
    override func rightMouseDown(with event: NSEvent) {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        let isFavourite = yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, isFavourite: historyItem) ?? false
        
        let menu = NSMenu(title: "Item")
        menu.autoenablesItems = false
        
        let paste = NSMenuItem(title: "Paste", action: #selector(pasteMenuItemClicked), keyEquivalent: "")
        let pastePlainText = NSMenuItem(title: "Paste as Plain Text", action: #selector(pastePlainTextMenuItemClicked), keyEquivalent: "")
        pastePlainText.isEnabled = historyItem.getUnstyledText() != nil
        let favourite = NSMenuItem(title: isFavourite ? "Remove from Favourites" : "Add to Favourites", action: #selector(favouriteButtonClicked), keyEquivalent: "")
        
        for menuItem in [paste, pastePlainText, favourite] {
            menuItem.target = self
        }
        menu.addItem(paste)
        menu.addItem(pastePlainText)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(favourite)
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func pasteMenuItemClicked() {
        requestPaste(plainText: false)
    }
    
    @objc private func pastePlainTextMenuItemClicked() {
        requestPaste(plainText: true)
    }
    
    private func requestPaste(plainText: Bool) {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didRequestPasteOf: historyItem, plainText: plainText)
    }
}
