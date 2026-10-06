//
//  HistorySettingsViewController.swift
//  Yippy
//

import Foundation
import Cocoa
import RxSwift

/// Settings tab for cleaning up the clipboard history automatically and reading the text in copied images.
///
/// Built in code like `IgnoredAppsSettingsViewController`, which it embeds for the list of apps whose copies expire.
class HistorySettingsViewController: NSViewController {

    private let maxAgePopUp = NSPopUpButton()
    private let recognizeTextCheckbox = NSButton(checkboxWithTitle: "Recognise text in copied images, so search finds them", target: nil, action: nil)
    private let expiringApps = IgnoredAppsSettingsViewController(
        bundleIds: State.main.expiringAppBundleIds,
        message: "Delete anything copied from these apps after a minute, and clear it from the clipboard, e.g. a terminal:",
        prompt: "Add"
    )

    private let disposeBag = DisposeBag()

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 420))

        let maxAgeLabel = NSTextField(labelWithString: "Delete clipboard items:")
        maxAgeLabel.translatesAutoresizingMaskIntoConstraints = false
        maxAgePopUp.translatesAutoresizingMaskIntoConstraints = false
        maxAgePopUp.addItems(withTitles: AutoClean.maxAgeDaysOptions.map({ $0.title }))
        maxAgePopUp.target = self
        maxAgePopUp.action = #selector(onMaxAgeChanged)
        let favouritesNote = NSTextField(wrappingLabelWithString: "Favourites are never deleted.")
        favouritesNote.translatesAutoresizingMaskIntoConstraints = false
        favouritesNote.textColor = .secondaryLabelColor

        recognizeTextCheckbox.translatesAutoresizingMaskIntoConstraints = false
        recognizeTextCheckbox.target = self
        recognizeTextCheckbox.action = #selector(onRecognizeTextChanged)
        let recognizeTextNote = NSTextField(wrappingLabelWithString: TextRecognizer.isAvailable
            ? "Each image is read once, in the background, when it's copied. Turning this on reads the images already saved."
            : "Needs macOS 10.15 or later.")
        recognizeTextNote.translatesAutoresizingMaskIntoConstraints = false
        recognizeTextNote.textColor = .secondaryLabelColor
        recognizeTextCheckbox.isEnabled = TextRecognizer.isAvailable

        addChild(expiringApps)
        let appsView = expiringApps.view
        appsView.translatesAutoresizingMaskIntoConstraints = false

        for subview in [maxAgeLabel, maxAgePopUp, favouritesNote, appsView, recognizeTextCheckbox, recognizeTextNote] {
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            maxAgeLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 23),
            maxAgeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            maxAgePopUp.firstBaselineAnchor.constraint(equalTo: maxAgeLabel.firstBaselineAnchor),
            maxAgePopUp.leadingAnchor.constraint(equalTo: maxAgeLabel.trailingAnchor, constant: 8),
            favouritesNote.topAnchor.constraint(equalTo: maxAgePopUp.bottomAnchor, constant: 6),
            favouritesNote.leadingAnchor.constraint(equalTo: maxAgeLabel.leadingAnchor),
            favouritesNote.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // The embedded list has its own 20 point margins
            appsView.topAnchor.constraint(equalTo: favouritesNote.bottomAnchor, constant: 4),
            appsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            appsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            appsView.heightAnchor.constraint(equalToConstant: 220),

            recognizeTextCheckbox.topAnchor.constraint(equalTo: appsView.bottomAnchor, constant: 4),
            recognizeTextCheckbox.leadingAnchor.constraint(equalTo: maxAgeLabel.leadingAnchor),
            recognizeTextNote.topAnchor.constraint(equalTo: recognizeTextCheckbox.bottomAnchor, constant: 4),
            recognizeTextNote.leadingAnchor.constraint(equalTo: maxAgeLabel.leadingAnchor, constant: 18),
            recognizeTextNote.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            recognizeTextNote.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
        ])

        self.view = view
        self.preferredContentSize = view.frame.size
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        State.main.maxItemAgeDays.subscribe(onNext: { [weak self] days in
            let i = AutoClean.maxAgeDaysOptions.firstIndex(where: { $0.days == days }) ?? 0
            self?.maxAgePopUp.selectItem(at: i)
        }).disposed(by: disposeBag)

        State.main.recognizesTextInImages.subscribe(onNext: { [weak self] in
            self?.recognizeTextCheckbox.state = $0 ? .on : .off
        }).disposed(by: disposeBag)
    }

    @objc private func onMaxAgeChanged() {
        let i = maxAgePopUp.indexOfSelectedItem
        guard AutoClean.maxAgeDaysOptions.indices.contains(i) else {
            return
        }
        State.main.maxItemAgeDays.accept(AutoClean.maxAgeDaysOptions[i].days)
    }

    @objc private func onRecognizeTextChanged() {
        State.main.recognizesTextInImages.accept(recognizeTextCheckbox.state == .on)
    }
}
