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
}
