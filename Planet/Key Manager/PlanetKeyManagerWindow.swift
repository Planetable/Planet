//
//  PlanetKeyManagerWindow.swift
//  Planet
//
//  Created by Kai on 3/9/23.
//

import Foundation
import Cocoa


class PlanetKeyManagerWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.miniaturizable, .closable, .resizable, .titled],  backing: .buffered, defer: true)
        self.collectionBehavior = .fullScreenNone
        self.minSize = NSMakeSize(320, 480)
        self.maxSize = NSMakeSize(640, CGFloat.infinity)
        self.title = "Key Manager"
        self.titlebarAppearsTransparent = false
        self.contentViewController = PlanetKeyManagerViewController()
        self.delegate = self
    }
}


extension PlanetKeyManagerWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
