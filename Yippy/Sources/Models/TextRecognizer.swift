//
//  TextRecognizer.swift
//  Yippy
//

import Foundation
import Cocoa
import Vision

/// Reads the text in copied images with Apple's Vision framework, so search can find screenshots by what they say.
///
/// Off unless "Recognise text in images" is on in the History settings tab. Images are read one at a time on a background queue,
/// and the text is saved in each item's `HistoryItemMetadata.recognizedText` ("" when there is none, so it isn't read again).
/// Needs macOS 10.15. Call everything on the main thread.
class TextRecognizer {

    /// Longer text is cut off, to keep the metadata file small.
    static let maxTextLength = 10_000

    static var isAvailable: Bool {
        if #available(OSX 10.15, *) {
            return true
        }
        return false
    }

    private let queue = DispatchQueue(label: "MatthewDavidson.Yippy.TextRecognizer", qos: .utility)

    /// Images waiting to be read.
    private var pending = [(history: History, id: UUID)]()
    private var isRunning = false
    /// Bumped when turned off, so an image being read when that happens is not saved.
    private var generation = 0

    var isEnabled = false {
        didSet {
            if !isEnabled {
                pending = []
                generation += 1
            }
        }
    }

    /// Queues the images among `items` that haven't been read yet.
    func enqueue(_ items: [HistoryItem], in history: History) {
        guard isEnabled else {
            return
        }
        for item in items where item.isImage && item.metadata.recognizedText == nil {
            if !pending.contains(where: { $0.id == item.fsId }) {
                pending.append((history: history, id: item.fsId))
            }
        }
        readNext()
    }

    private func readNext() {
        guard isEnabled, !isRunning else {
            return
        }
        var next: (history: History, id: UUID, data: Data)?
        while next == nil && !pending.isEmpty {
            let (history, id) = pending.removeFirst()
            // Skip items deleted or read since they were queued
            if let item = history.items.first(where: { $0.fsId == id }), item.metadata.recognizedText == nil,
               let data = item.data(forType: .png) ?? item.data(forType: .tiff) {
                next = (history: history, id: id, data: data)
            }
        }
        guard let image = next else {
            return
        }
        let (history, id, data) = image

        isRunning = true
        let g = generation
        queue.async {
            let text = Self.recognizeText(inImageData: data)
            DispatchQueue.main.async {
                self.isRunning = false
                if g == self.generation {
                    history.updateMetadata(ofItemWithId: id) { $0.recognizedText = text ?? "" }
                }
                self.readNext()
            }
        }
    }

    /// The text in the image, one line per line of text, or nil if it couldn't be read.
    static func recognizeText(inImageData data: Data) -> String? {
        guard #available(OSX 10.15, *) else {
            return nil
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        do {
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
        }
        catch {
            return nil
        }
        let results: [Any] = request.results ?? []
        let lines = results.compactMap({ ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string })
        return String(lines.joined(separator: "\n").prefix(maxTextLength))
    }
}
