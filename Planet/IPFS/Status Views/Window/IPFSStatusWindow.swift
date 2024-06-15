//
//  IPFSStatusWindow.swift
//  Planet
//

import Foundation
import Cocoa


class IPFSStatusWindow: NSWindow {
    static let minWidth: CGFloat = 280
    static let minHeight: CGFloat = 280

    init(withOrigin origin: NSPoint) {
        let windowOrigin: NSPoint = {
            if origin == .zero {
                let screenFrame = NSScreen.main!.frame
                let x = (screenFrame.width - Self.minWidth) / 2
                let y = (screenFrame.height - Self.minHeight) / 2
                return NSPoint(x: x, y: y)
            }
            return origin
        }()
        super.init(contentRect: NSRect(origin: windowOrigin, size: .init(width: Self.minWidth, height: Self.minHeight)), styleMask: [.closable, .titled, .fullSizeContentView], backing: .buffered, defer: true)
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
        Task { @MainActor in
            IPFSState.shared.isShowingStatusWindow = false
        }
        return true
    }
}
