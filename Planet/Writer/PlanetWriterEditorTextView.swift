//
//  PlanetWriterEditorTextView.swift
//  Planet
//
//  Created by Kai on 3/29/22.
//

import Cocoa


class PlanetWriterEditorTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        return [.string]
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        return [.fileURL]
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
        guard let _ = PlanetStore.shared.currentPlanet else { return }
        let sequenceNumber = sender.draggingSequenceNumber
        let offsetX = sender.draggingLocation.x
        let offsetY = sender.draggingLocation.y
        Task { @MainActor in
            guard PlanetWriterViewModel.shared.validateDragginInfo(sequenceNumber: sequenceNumber, location: NSPoint(x: offsetX, y: offsetY)) else { return }
            let pboard = sender.draggingPasteboard
            if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL] {
                let activeTargetID = PlanetWriterViewModel.shared.activeTargetID
                if let activeID = PlanetWriterViewModel.shared.editings[activeTargetID] {
                    PlanetWriterManager.shared.processUploadings(urls: urls, targetID: activeTargetID, insertURLs: true, inEditMode: activeID != activeTargetID)
                }
            }
        }
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
}
