//
//  AppWindow.swift
//  PlanetLite
//

import Cocoa


class AppWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.collectionBehavior = .fullScreenNone
        self.titlebarAppearsTransparent = false
        self.title = "Planet Lite"
        self.subtitle = ""
        self.toolbarStyle = .unified
        self.contentViewController = AppContainerViewController()
        self.delegate = self
    }
}


extension AppWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
