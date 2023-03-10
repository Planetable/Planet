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
    
    private func generateKeyData() throws -> (PlanetKeyItem, Data) {
        guard let selectedKeyItemID = PlanetKeyManagerViewModel.shared.selectedKeyItemID, let keyItem = PlanetKeyManagerViewModel.shared.keys.first(where: { $0.id == selectedKeyItemID }) else { throw PlanetError.KeychainGeneratingKeyError }
        let tmpKeyPath = URLUtils.temporaryPath.appendingPathComponent(keyItem.keyName).appendingPathExtension("pem")
        defer {
            try? FileManager.default.removeItem(at: tmpKeyPath)
        }
        if FileManager.default.fileExists(atPath: tmpKeyPath.path) {
            try FileManager.default.removeItem(at: tmpKeyPath)
        }
        let (ret, _, _) = try IPFSCommand.exportKey(name: keyItem.keyName, target: tmpKeyPath, format: "pem-pkcs8-cleartext").run()
        if ret != 0 {
            throw PlanetError.IPFSError
        }
        return (keyItem, try Data(contentsOf: tmpKeyPath))
    }
    
    private func reloadPlanetKeys() {
        Task { @MainActor in
            await PlanetKeyManagerViewModel.shared.reloadPlanetKeys()
        }
    }
    
    private func syncForSelectedKeyItem() throws {
        guard let selectedKeyItemID = PlanetKeyManagerViewModel.shared.selectedKeyItemID, let keyItem = PlanetKeyManagerViewModel.shared.keys.first(where: { $0.id == selectedKeyItemID }) else { throw PlanetError.KeychainGeneratingKeyError }
        let keychainExists: Bool = KeychainHelper.shared.check(forKey: .keyPrefix + keyItem.keyName)
        let keystoreExists: Bool = PlanetKeyManagerViewModel.shared.keysInKeystore.contains(keyItem.keyName)
        defer {
            reloadPlanetKeys()
            let tmpKeyPath = URLUtils.temporaryPath.appendingPathComponent(keyItem.keyName).appendingPathExtension("pem")
            if FileManager.default.fileExists(atPath: tmpKeyPath.path) {
                try? FileManager.default.removeItem(at: tmpKeyPath)
            }
        }
        /*
            0. abort if not exists in both locations.
            1. keystore -> keychain
            2. keychain -> keystore
         */
        if !keychainExists && !keystoreExists {
            throw PlanetError.KeychainGeneratingKeyError
        } else if keystoreExists && !keychainExists {
            let (_, keyData) = try generateKeyData()
            try KeychainHelper.shared.saveData(keyData, forKey: .keyPrefix + keyItem.keyName)
        } else if keychainExists && !keystoreExists {
            let theKeyData = try KeychainHelper.shared.loadData(forKey: .keyPrefix + keyItem.keyName, withICloudSync: true)
            let tmpKeyPath = URLUtils.temporaryPath.appendingPathComponent(keyItem.keyName).appendingPathExtension("pem")
            if FileManager.default.fileExists(atPath: tmpKeyPath.path) {
                try FileManager.default.removeItem(at: tmpKeyPath)
            }
            try theKeyData.write(to: tmpKeyPath)
            try IPFSCommand.importKey(name: keyItem.keyName, target: tmpKeyPath, format: "pem-pkcs8-cleartext").run()
        }
    }
    
    private func importForSelectedKeyItem() throws {
        guard let selectedKeyItemID = PlanetKeyManagerViewModel.shared.selectedKeyItemID, let keyItem = PlanetKeyManagerViewModel.shared.keys.first(where: { $0.id == selectedKeyItemID }) else { throw PlanetError.KeychainImportingKeyError }
        if PlanetKeyManagerViewModel.shared.keysInKeystore.contains(keyItem.keyName) {
            throw PlanetError.KeychainImportingKeyExistsError
        } else {
            let panel = NSOpenPanel()
            panel.message = "Choose key file to import"
            panel.prompt = "Choose"
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.data]
            panel.canChooseDirectories = false
            let response = panel.runModal()
            guard response == .OK, let url = panel.url else { return }
            let keyData = try Data(contentsOf: url)
            try IPFSCommand.importKey(name: keyItem.keyName, target: url, format: "pem-pkcs8-cleartext").run()
            try KeychainHelper.shared.saveData(keyData, forKey: .keyPrefix + keyItem.keyName)
            self.reloadPlanetKeys()
        }
    }
    
    private func exportForSelectedKeyItem() throws {
        let (keyItem, keyData) = try generateKeyData()
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
        let targetKeyPath = url.appendingPathComponent("\(keyItem.planetName.sanitized()).pem")
        if FileManager.default.fileExists(atPath: targetKeyPath.path) {
            throw PlanetError.KeychainExportingKeyExistsError
        }
        try keyData.write(to: targetKeyPath)
        NSWorkspace.shared.activateFileViewerSelecting([targetKeyPath])
    }
    
    @objc private func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
        case .keyManagerReloadItem:
            reloadPlanetKeys()
        case .keyManagerImportItem:
            do {
                try importForSelectedKeyItem()
            } catch {
                debugPrint("failed to import for selected key item: \(error)")
                let alert = NSAlert()
                alert.messageText = "Failed to Import Planet Key"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "Cancel")
                let _ = alert.runModal()
            }
        case .keyManagerExportItem:
            do {
                try exportForSelectedKeyItem()
            } catch {
                debugPrint("failed to export for selected key item: \(error)")
                let alert = NSAlert()
                alert.messageText = "Failed to Export Planet Key"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "Cancel")
                let _ = alert.runModal()
            }
        case .keyManagerSyncItem:
            do {
                try syncForSelectedKeyItem()
            } catch {
                debugPrint("failed to sync for selected key item: \(error)")
                let alert = NSAlert()
                alert.messageText = "Failed to Sync Planet Key to Keychain"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "Cancel")
                let _ = alert.runModal()
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
