//
//  TBWindow.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import Cocoa

class TBWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.collectionBehavior = .fullScreenNone
        self.title = "Template Browser"
        self.titlebarAppearsTransparent = false
        self.toolbarStyle = .unified
        self.contentViewController = TBContainerViewController()
        self.delegate = self
    }
}

extension TBWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? TBWindow {
            window.delegate = nil
            PlanetAppDelegate.shared.templateWindowController = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.contentView = nil
        sender.contentViewController = nil
        return true
    }
}
