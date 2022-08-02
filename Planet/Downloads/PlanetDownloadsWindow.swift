//
//  PlanetDownloadsWindow.swift
//  Planet
//
//  Created by Kai on 8/1/22.
//

import Cocoa


class PlanetDownloadsWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.miniaturizable, .closable, .resizable, .titled],  backing: .buffered, defer: true)
        self.collectionBehavior = .fullScreenNone
        self.minSize = NSMakeSize(320, 480)
        self.maxSize = NSMakeSize(640, CGFloat.infinity)
        self.title = "Downloads"
        self.titlebarAppearsTransparent = false
        self.contentViewController = PlanetDownloadsViewController()
        self.delegate = self
    }
}


extension PlanetDownloadsWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? PlanetDownloadsWindow {
            window.delegate = nil
            PlanetAppDelegate.shared.downloadsWindowController = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.contentView = nil
        sender.contentViewController = nil
        return true
    }
}
