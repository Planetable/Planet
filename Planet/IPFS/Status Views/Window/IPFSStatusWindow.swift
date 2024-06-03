//
//  IPFSStatusWindow.swift
//  Planet
//

import Foundation
import Cocoa


class IPFSStatusWindow: NSWindow {
    static let minWidth: CGFloat = 280
    static let minHeight: CGFloat = 280

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: .init(width: Self.minWidth, height: Self.minHeight)), styleMask: [.closable, .titled, .fullSizeContentView], backing: .buffered, defer: true)
        self.minSize = CGSize(width: Self.minWidth, height: Self.minHeight)
        self.collectionBehavior = .fullScreenNone
        self.title = "IPFS Status"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .visible
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.delegate = self
        self.setFrameAutosaveName("IPFSStatusWindow")
    }
}


extension IPFSStatusWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
