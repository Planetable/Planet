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
        self.titlebarAppearsTransparent = false
        self.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "WriterToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        self.toolbar = toolbar
        // self.title = "Writer " + writerID.uuidString.prefix(4)
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
    
    @objc func send(_ sender: Any?) {
        NotificationCenter.default.post(name: .sendArticle, object: writerID)
    }
}


// MARK: - NSToolbarDelegate

extension NSToolbarItem.Identifier {
    static let send = NSToolbarItem.Identifier("send")
}


extension PlanetWriterWindow: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .send:
            let title = NSLocalizedString("Send", comment: "Send")
            return makeToolbarButton(.send, title, NSImage(systemSymbolName: "paperplane", accessibilityDescription: "Send")!, "send:")
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .send,
            .flexibleSpace
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .send
        ]
    }
    
    func toolbarWillAddItem(_ notification: Notification) {
        guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
            return
        }
    }
    
    func toolbarDidRemoveItem(_ notification: Notification) {
        guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
            return
        }
    }
    
    func makeToolbarButton(_ itemIdentifier: NSToolbarItem.Identifier, _ title: String, _ image: NSImage, _ selector: String) -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.autovalidates = true
        
        switch itemIdentifier {
        case .send:
            toolbarItem.isNavigational = true
        default:
            toolbarItem.isNavigational = false
        }
        
        let button = NSButton()
        button.bezelStyle = .texturedRounded
        button.image = image
        button.imageScaling = .scaleProportionallyDown
        button.action = Selector((selector))
        
        toolbarItem.view = button
        toolbarItem.toolTip = title
        toolbarItem.label = title
        return toolbarItem
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
