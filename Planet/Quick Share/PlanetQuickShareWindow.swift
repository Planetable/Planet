//
//  PlanetQuickShareWindow.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import Foundation
import Cocoa


class PlanetQuickShareWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.titled, .fullSizeContentView],  backing: .buffered, defer: true)
        self.collectionBehavior = .fullScreenNone
        self.minSize = NSMakeSize(.sheetWidth, .sheetHeight)
        self.maxSize = NSMakeSize(.sheetWidth, .sheetHeight)
        self.isMovableByWindowBackground = true
        self.title = ""
        self.titlebarAppearsTransparent = true
        self.toolbarStyle = .unifiedCompact
        self.contentViewController = PlanetQuickShareViewController()
        self.delegate = self
    }
}


extension PlanetQuickShareWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        self.level = .statusBar
    }
    
    // MARK: - Events -
    
    override func mouseDown(with event: NSEvent) {
        self.performDrag(with: event)
    }
    
}
