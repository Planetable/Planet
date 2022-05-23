//
//  PlanetWriterEditorTextView.swift
//  Planet
//
//  Created by Kai on 3/29/22.
//

import Cocoa


class PlanetWriterEditorTextView: NSTextView {
    private var urls: [URL] = []

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        return [.string]
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        return [NSPasteboard.PasteboardType.fileURL]
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard let sender = sender else { return }
        Task { @MainActor in
            let activeTargetID = PlanetWriterViewModel.shared.activeTargetID
            if let _ = PlanetWriterViewModel.shared.editings[activeTargetID] {
                PlanetWriterViewModel.shared.updateDraggingInfo(sequenceNumber: sender.draggingSequenceNumber, location: sender.draggingLocation)
            }
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        guard let _ = PlanetStore.shared.currentPlanet, urls.count > 0 else { return }
        let sequenceNumber = sender.draggingSequenceNumber
        let offsetX = sender.draggingLocation.x
        let offsetY = sender.draggingLocation.y
        let targetURLs = urls
        Task { @MainActor in
            guard PlanetWriterViewModel.shared.validateDragginInfo(sequenceNumber: sequenceNumber, location: NSPoint(x: offsetX, y: offsetY)) else { return }
            let activeTargetID = PlanetWriterViewModel.shared.activeTargetID
            if let activeID = PlanetWriterViewModel.shared.editings[activeTargetID] {
                PlanetWriterManager.shared.processUploadings(urls: targetURLs, targetID: activeTargetID, insertURLs: true, inEditMode: activeID != activeTargetID)
            }
        }
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        self.urls = processURLs(fromSender: sender)
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    private func processURLs(fromSender sender: NSDraggingInfo) -> [URL] {
        if let pasteBoardItems = sender.draggingPasteboard.pasteboardItems {
            let urls: [URL] = pasteBoardItems
                .compactMap({
                    return $0.propertyList(forType: .fileURL) as? String
                })
                .map({
                    let url = URL(fileURLWithPath: $0).standardized
                    return url
                })
            return urls
        }
        return []
    }
}
