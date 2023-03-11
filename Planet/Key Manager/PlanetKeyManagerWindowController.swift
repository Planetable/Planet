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
    
    @MainActor
    private func syncForSelectedKeyItem() throws {
        guard let selectedKeyItemID = PlanetKeyManagerViewModel.shared.selectedKeyItemID, let keyItem = PlanetKeyManagerViewModel.shared.keys.first(where: { $0.id == selectedKeyItemID }) else { throw PlanetError.KeyManagerGeneratingKeyError }
        let keychainExists: Bool = KeychainHelper.shared.check(forKey: .keyPrefix + keyItem.keyName)
        let keystoreExists: Bool = PlanetKeyManagerViewModel.shared.keysInKeystore.contains(keyItem.keyName)
        /*
            0. Abort if not exists in both locations.
            1. Sync: keystore -> keychain
            2. Sync: keychain -> keystore
         */
        if !keychainExists && !keystoreExists {
            throw PlanetError.KeyManagerGeneratingKeyError
        } else if keystoreExists && !keychainExists {
            try KeychainHelper.shared.exportKeyToKeychain(forPlanetKeyName: keyItem.keyName)
        } else if keychainExists && !keystoreExists {
            try KeychainHelper.shared.importKeyFromKeychain(forPlanetKeyName: keyItem.keyName)
        }
        reloadPlanetKeys()
    }
    
    @MainActor
    private func importForSelectedKeyItem() throws {
        guard let selectedKeyItemID = PlanetKeyManagerViewModel.shared.selectedKeyItemID, let keyItem = PlanetKeyManagerViewModel.shared.keys.first(where: { $0.id == selectedKeyItemID }) else { throw PlanetError.KeyManagerImportingKeyError }
        if PlanetKeyManagerViewModel.shared.keysInKeystore.contains(keyItem.keyName) {
            throw PlanetError.KeyManagerImportingKeyExistsError
        } else {
            let panel = NSOpenPanel()
            panel.message = "Choose key file to import"
            panel.prompt = "Choose"
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.data]
            panel.canChooseDirectories = false
            let response = panel.runModal()
            guard response == .OK, let url = panel.url else { return }
            try KeychainHelper.shared.importKeyFile(forPlanetKeyName: keyItem.keyName, fileURL: url)
        }
        reloadPlanetKeys()
    }
    
    @MainActor
    private func exportForSelectedKeyItem() throws {
        guard let selectedKeyItemID = PlanetKeyManagerViewModel.shared.selectedKeyItemID, let keyItem = PlanetKeyManagerViewModel.shared.keys.first(where: { $0.id == selectedKeyItemID }) else { throw PlanetError.KeyManagerImportingKeyError }
        let panel = NSOpenPanel()
        panel.message = "Choose location to save planet key"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        let targetKeyPath = try KeychainHelper.shared.exportKeyFile(forPlanetName: keyItem.planetName, planetKeyName: keyItem.keyName, toDirectory: url)
        NSWorkspace.shared.activateFileViewerSelecting([targetKeyPath])
    }
    
    @objc private func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
        case .keyManagerReloadItem:
            reloadPlanetKeys()
        case .keyManagerImportItem:
            Task { @MainActor in
                do {
                    try importForSelectedKeyItem()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Import Planet Key"
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: "Cancel")
                    let _ = alert.runModal()
                }
            }
        case .keyManagerExportItem:
            Task { @MainActor in
                do {
                    try exportForSelectedKeyItem()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Export Planet Key"
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: "Cancel")
                    let _ = alert.runModal()
                }
            }
        case .keyManagerSyncItem:
            Task { @MainActor in
                do {
                    try syncForSelectedKeyItem()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Sync Planet Key to Keychain"
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: "Cancel")
                    let _ = alert.runModal()
                }
            }
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
            item.paletteLabel = "Sync with Keychain"
            item.toolTip = "Sync with Keychain"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "key.icloud", accessibilityDescription: "Sync with Keychain")
            return item
        case .keyManagerImportItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Import"
            item.paletteLabel = "Import Planet Key"
            item.toolTip = "Import Planet Key"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: "Import Planet Key")
            return item
        case .keyManagerExportItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Export"
            item.paletteLabel = "Export Planet Key"
            item.toolTip = "Export Planet Key"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "arrow.up.doc", accessibilityDescription: "Export Planet Key")
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
