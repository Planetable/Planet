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

    override func draggingEnded(_ sender: NSDraggingInfo) {
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL] {
            debugPrint("got urls: \(urls)")
        }
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.copy
    }
}
