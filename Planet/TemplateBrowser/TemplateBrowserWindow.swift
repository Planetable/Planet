//
//  TemplateBrowserWindow.swift
//  Planet
//
//  Created by Xin Liu on 4/13/22.
//

import Foundation
import Cocoa
import SwiftUI

class TemplateBrowserWindow: NSWindow {
    init(rect: NSRect, maskStyle style: NSWindow.StyleMask, backingType: NSWindow.BackingStoreType, deferMode flag: Bool) {
        super.init(contentRect: rect, styleMask: style, backing: backingType, defer: flag)
        self.titleVisibility = .visible
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.title = "Template Browser"
        self.delegate = self
        self.isReleasedWhenClosed = false
    }
}


extension TemplateBrowserWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .closeTemplateBrowserWindow, object: nil)
    }
}

