//
//  PlanetWriterWindow.swift
//  Planet
//
//  Created by Kai on 2/22/22.
//

import Cocoa
import SwiftUI


class PlanetWriterWindow: NSWindow {
    var writerID: UUID

    init(rect: NSRect, maskStyle style: NSWindow.StyleMask, backingType: NSWindow.BackingStoreType, deferMode flag: Bool, writerID id: UUID) {
        writerID = id
        super.init(contentRect: rect, styleMask: style, backing: backingType, defer: flag)
        self.titleVisibility = .visible
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.title = "Writer " + writerID.uuidString.prefix(4)
        self.delegate = self
        self.isReleasedWhenClosed = false
        PlanetStore.shared.writerIDs.insert(id)
        PlanetStore.shared.activeWriterID = id
        Task.detached(priority: .utility) {
            await MainActor.run {
                PlanetWriterViewModel.shared.updateActiveID(articleID: self.writerID)
            }
        }
    }
}


extension PlanetWriterWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .closeWriterWindow, object: writerID)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        Task.detached(priority: .utility) {
            await MainActor.run {
                PlanetWriterViewModel.shared.updateActiveID(articleID: self.writerID)
            }
        }
    }
}
