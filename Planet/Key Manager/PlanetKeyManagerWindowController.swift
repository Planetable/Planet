//
//  PlanetKeyManagerWindowController.swift
//  Planet
//
//  Created by Kai on 3/9/23.
//

import Foundation
import Cocoa


class PlanetKeyManagerWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let windowSize = NSSize(width: 320, height: 480)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = PlanetKeyManagerWindow(contentRect: rect, styleMask: [], backing: .buffered, defer: true)
        super.init(window: w)
        self.setupToolbar()
        self.window?.setFrameAutosaveName("Planet Key Manager Window")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    private func setupToolbar() {
        guard let w = self.window else { return }
        let toolbar = NSToolbar(identifier: .keyManagerToolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        w.title = "Key Manager"
        w.toolbar = toolbar
        w.toolbar?.validateVisibleItems()
    }
    
    private func reloadPlanetKeys() {
        Task { @MainActor in
            await PlanetKeyManagerViewModel.shared.reloadPlanetKeys()
        }
    }
    
    private func syncForSelectedKeyItem() {
        let viewModel = PlanetKeyManagerViewModel.shared
        guard let selectedKeyItemID = viewModel.selectedKeyItemID, let keyItem = viewModel.keys.first(where: { $0.id == selectedKeyItemID }) else { return }
        // MARK: TODO: sync into keychain
    }
    
    private func importForSelectedKeyItem() {
        debugPrint("import item")
    }
    
    private func exportForSelectedKeyItem() {
        debugPrint("export item")
    }
    
    @objc private func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
        case .keyManagerReloadItem:
            reloadPlanetKeys()
        case .keyManagerImportItem:
            importForSelectedKeyItem()
        case .keyManagerExportItem:
            exportForSelectedKeyItem()
        case .keyManagerSyncItem:
            syncForSelectedKeyItem()
        default:
            break
        }
    }
}


// MARK: - Toolbar Validation

extension PlanetKeyManagerWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .keyManagerReloadItem:
            return true
        case .keyManagerSyncItem, .keyManagerImportItem, .keyManagerExportItem:
            return PlanetKeyManagerViewModel.shared.selectedKeyItemID != nil
        default:
            return false
        }
    }
}


// MARK: - Toolbar Delegate

extension PlanetKeyManagerWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .keyManagerReloadItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Reload"
            item.paletteLabel = "Reload Planet Keys"
            item.toolTip = "Reload Planet Keys"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload Planet Keys")
            return item
        case .keyManagerSyncItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Sync"
            item.paletteLabel = "Sync to Keychain"
            item.toolTip = "Sync to Keychain"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "key", accessibilityDescription: "Sync to Keychain")
            return item
        case .keyManagerImportItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Import"
            item.paletteLabel = "Import Planet Key"
            item.toolTip = "Import Planet Key"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Import Planet Key")
            return item
        case .keyManagerExportItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Export"
            item.paletteLabel = "Export Planet Key"
            item.toolTip = "Export Planet Key"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export Planet Key")
            return item
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .keyManagerSyncItem,
            .keyManagerImportItem,
            .keyManagerExportItem,
            .keyManagerReloadItem
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .keyManagerSyncItem,
            .keyManagerImportItem,
            .keyManagerExportItem,
            .keyManagerReloadItem
        ]
    }
    
    func toolbarImmovableItemIdentifiers(_ toolbar: NSToolbar) -> Set<NSToolbarItem.Identifier> {
        return [
            .flexibleSpace,
            .keyManagerSyncItem,
            .keyManagerImportItem,
            .keyManagerExportItem,
            .keyManagerReloadItem
        ]
    }

    func toolbarWillAddItem(_ notification: Notification) {
    }

    func toolbarDidRemoveItem(_ notification: Notification) {
        setupToolbar()
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }
}
