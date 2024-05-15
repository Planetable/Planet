//
//  IPFSOpenWindow.swift
//  Planet
//

import Foundation
import Cocoa


class IPFSOpenWindow: NSWindow {
    static let minWidth: CGFloat = 300
    static let minHeight: CGFloat = 64
    
    init() {
        super.init(contentRect: NSRect(origin: .zero, size: .init(width: Self.minWidth, height: Self.minHeight)), styleMask: [.miniaturizable, .closable, .resizable, .titled], backing: .buffered, defer: true)
        self.minSize = CGSize(width: Self.minWidth, height: Self.minHeight)
        self.collectionBehavior = .fullScreenNone
        self.title = "Open IPFS Resource"
        self.titlebarAppearsTransparent = false
        self.titleVisibility = .visible
        self.delegate = self
        self.setFrameAutosaveName("IPFSOpenWindow")
        self.center()
    }
}


extension IPFSOpenWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
