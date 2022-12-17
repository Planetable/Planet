//
//  PFDashboardWindow.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import Cocoa


class PFDashboardWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.collectionBehavior = .fullScreenNone
        self.title = "Published Folders Dashboard"
        self.titlebarAppearsTransparent = false
        self.toolbarStyle = .unified
        self.contentViewController = PFDashboardContainerViewController()
        self.delegate = self
    }
}


extension PFDashboardWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? PFDashboardWindow {
            window.delegate = nil
            PlanetAppDelegate.shared.publishedFoldersDashboardWindowController = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.contentView = nil
        sender.contentViewController = nil
        return true
    }
}
