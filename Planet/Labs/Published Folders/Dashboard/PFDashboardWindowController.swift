//
//  PFDashboardWindowController.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import Cocoa
import UserNotifications


class PFDashboardWindowController: NSWindowController {
    
    override init(window: NSWindow?) {
        let windowSize = NSSize(width: .sidebarWidth + .contentWidth + .inspectorWidth, height: 320)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = PFDashboardWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView, .unifiedTitleAndToolbar], backing: .buffered, defer: true)
        w.minSize = windowSize
        w.maxSize = NSSize(width: screenSize.width, height: .infinity)
        w.toolbarStyle = .unified
        super.init(window: w)
        self.setupToolbar()
        self.window?.setFrameAutosaveName("Published Folders Dashboard Window")
        NotificationCenter.default.addObserver(forName: .dashboardInspectorIsCollapsedStatusChanged, object: nil, queue: .main) { [weak self] _ in
            self?.setupToolbar()
        }
        NotificationCenter.default.addObserver(forName: .dashboardRefreshToolbar, object: nil, queue: .main) { [weak self] _ in
            self?.setupToolbar()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .dashboardInspectorIsCollapsedStatusChanged, object: nil)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    private func setupToolbar() {
        guard let w = self.window else { return }
        let toolbar = NSToolbar(identifier: .dashboardToolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        w.title = "Published Folders Dashboard"
        w.subtitle = ""
        w.toolbar = toolbar
        w.toolbar?.validateVisibleItems()
        let serviceStore = PlanetPublishedServiceStore.shared
        if let selectedID = serviceStore.selectedFolderID, let folder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }) {
            w.title = folder.url.lastPathComponent
            w.subtitle = "Never Published"
            if let date = folder.published {
                w.subtitle = "Last Published: " + date.relativeDateDescription()
            }
        }
    }
    
    @objc func openInPublicGateway(_ sender: Any) {
        guard let object = sender as? NSMenuItem, let url = object.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc func openInLocalhost(_ sender: Any) {
        guard let object = sender as? NSMenuItem, let url = object.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc func revealInFinder(_ sender: Any) {
        guard let object = sender as? NSMenuItem, let folder = object.representedObject as? PlanetPublishedFolder else { return }
        let serviceStore = PlanetPublishedServiceStore.shared
        serviceStore.revealFolderInFinder(folder)
    }
    
    @objc func publishFolder(_ sender: Any) {
        guard let object = sender as? NSMenuItem, let folder = object.representedObject as? PlanetPublishedFolder else { return }
        let serviceStore = PlanetPublishedServiceStore.shared
        guard !serviceStore.publishingFolders.contains(folder.id) else {
            let alert = NSAlert()
            alert.messageText = "Failed to Publish Folder"
            alert.informativeText = "Folder is in publishing progress, please try again later."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        Task { @MainActor in
            do {
                try await serviceStore.publishFolder(folder, skipCIDCheck: true)
                let content = UNMutableNotificationContent()
                content.title = "Folder Published"
                content.subtitle = folder.url.absoluteString
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: folder.id.uuidString,
                    content: content,
                    trigger: trigger
                )
                try? await UNUserNotificationCenter.current().add(request)
            } catch PlanetError.PublishedServiceFolderUnchangedError {
                let alert = NSAlert()
                alert.messageText = "Failed to Publish Folder"
                alert.informativeText = "Folder content hasn't changed since last publish."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                debugPrint("Failed to publish folder: \(folder), error: \(error)")
                let alert = NSAlert()
                alert.messageText = "Failed to Publish Folder"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    @objc func backupFolderKey(_ sender: Any) {
        guard let object = sender as? NSMenuItem, let folder = object.representedObject as? PlanetPublishedFolder else { return }
        let serviceStore = PlanetPublishedServiceStore.shared
        serviceStore.exportFolderKey(folder)
    }
    
    @objc func removeFolder(_ sender: Any) {
        guard let object = sender as? NSMenuItem, let folder = object.representedObject as? PlanetPublishedFolder else { return }
        let serviceStore = PlanetPublishedServiceStore.shared
        guard !serviceStore.publishingFolders.contains(folder.id) else {
            let alert = NSAlert()
            alert.messageText = "Failed to Remove Folder"
            alert.informativeText = "Folder is in publishing progress, please try again later."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        serviceStore.addToRemovingPublishedFolderQueue(folder)
        let updatedFolders = serviceStore.publishedFolders.filter { f in
            return f.id != folder.id
        }
        Task { @MainActor in
            serviceStore.updatePublishedFolders(updatedFolders)
        }
    }
    
    @objc func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
        case .dashboardSidebarItem:
            if let vc = self.window?.contentViewController as? PFDashboardContainerViewController {
                vc.toggleSidebar(sender)
            }
        case .dashboardAddItem:
            addFolder()
        case .dashboardShareItem:
            break
        case .dashboardActionItem:
            break
        case .dashboardBackwardItem:
            NotificationCenter.default.post(name: .dashboardWebViewGoBackward, object: nil)
            break
        case .dashboardForwardItem:
            NotificationCenter.default.post(name: .dashboardWebViewGoForward, object: nil)
            break
        case .dashboardReloadItem:
            NotificationCenter.default.post(name: .dashboardReloadWebView, object: nil)
        case .dashboardHomeItem:
            NotificationCenter.default.post(name: .dashboardWebViewGoHome, object: nil)
        case .dashboardInspectorItem:
            if let vc = self.window?.contentViewController as? PFDashboardContainerViewController, let inspectorItem = vc.splitViewItems.last {
                inspectorItem.animator().isCollapsed.toggle()
                UserDefaults.standard.set(inspectorItem.isCollapsed, forKey: String.dashboardInspectorIsCollapsed)
            }
        default:
            break
        }
    }
}


// MARK: - Toolbar Item Actions

extension PFDashboardWindowController {
    func addFolder() {
        PlanetPublishedServiceStore.shared.addFolder()
    }
}


// MARK: - Toolbar Validation

extension PFDashboardWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .dashboardAddItem:
            return true
        case .dashboardShareItem:
            return true
        case .dashboardActionItem:
            return true
        case .dashboardBackwardItem:
            return PlanetPublishedServiceStore.shared.selectedFolderCanGoBackward
        case .dashboardForwardItem:
            return PlanetPublishedServiceStore.shared.selectedFolderCanGoForward
        case .dashboardReloadItem:
            return true
        case .dashboardHomeItem:
            return true
        case .dashboardSidebarItem:
            return true
        case .dashboardInspectorItem:
            return true
        default:
            return false
        }
    }
}

// MARK: - Toolbar Delegate

extension PFDashboardWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .dashboardSidebarItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Toggle Sidebar"
            item.paletteLabel = "Toggle Sidebar"
            item.toolTip = "Toggle Sidebar"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            return item
        case .dashboardSidebarSeparatorItem:
            if let vc = self.window?.contentViewController as? PFDashboardContainerViewController {
                let item = NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: vc.splitView, dividerIndex: 0)
                return item
            } else {
                return nil
            }
        case .dashboardAddItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Add"
            item.paletteLabel = "Add Folder"
            item.toolTip = "Add Folder"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add Folder")
            return item
        case .dashboardShareItem:
            let item = NSSharingServicePickerToolbarItem(itemIdentifier: itemIdentifier)
            item.delegate = self
            item.menuFormRepresentation?.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
            item.toolTip = "Share"
            return item
        case .dashboardBackwardItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Backward"
            item.paletteLabel = "Backward"
            item.toolTip = "Backward"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "chevron.backward", accessibilityDescription: "Backward")
            return item
        case .dashboardForwardItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Forward"
            item.paletteLabel = "Forward"
            item.toolTip = "Forward"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "chevron.forward", accessibilityDescription: "Forward")
            return item
        case .dashboardHomeItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Home"
            item.paletteLabel = "Home"
            item.toolTip = "Home"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "house", accessibilityDescription: "Home")
            return item
        case .dashboardReloadItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Reload"
            item.paletteLabel = "Reload"
            item.toolTip = "Reload"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
            return item
        case .dashboardActionItem:
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.showsIndicator = true
            item.label = "More"
            item.paletteLabel = "More Actions"
            item.toolTip = "Displays available actions"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "")
            let serviceStore = PlanetPublishedServiceStore.shared
            if let selectedID = serviceStore.selectedFolderID, let folder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }) {
                let menu = NSMenu()
                if let _ = folder.published, let publishedLink = folder.publishedLink {
                    if let gatewayURL = URL(string: "\(IPFSDaemon.preferredGateway())/ipns/\(publishedLink)") {
                        let publicGatewayActionItem = NSMenuItem()
                        publicGatewayActionItem.representedObject = gatewayURL
                        publicGatewayActionItem.title = "Open in Public Gateway"
                        publicGatewayActionItem.target = self
                        publicGatewayActionItem.action = #selector(self.openInPublicGateway(_:))
                        menu.addItem(publicGatewayActionItem)
                    }
                    if let localhostURL = URL(string: "\(IPFSDaemon.shared.gateway)/ipns/\(publishedLink)") {
                        let localhostActionItem = NSMenuItem()
                        localhostActionItem.representedObject = localhostURL
                        localhostActionItem.title = "Open in Localhost"
                        localhostActionItem.target = self
                        localhostActionItem.action = #selector(self.openInLocalhost(_:))
                        menu.addItem(localhostActionItem)
                    }
                }
                
                let revealFinderItem = NSMenuItem()
                revealFinderItem.representedObject = folder
                revealFinderItem.title = "Reveal in Finder"
                revealFinderItem.target = self
                revealFinderItem.action = #selector(self.revealInFinder(_:))
                menu.addItem(revealFinderItem)
                
                let publishFolderItem = NSMenuItem()
                publishFolderItem.representedObject = folder
                publishFolderItem.title = "Publish Folder"
                publishFolderItem.target = self
                publishFolderItem.action = #selector(self.publishFolder(_:))
                menu.addItem(publishFolderItem)
                
                menu.addItem(NSMenuItem.separator())
                
                let backupFolderKeyItem = NSMenuItem()
                backupFolderKeyItem.representedObject = folder
                backupFolderKeyItem.title = "Backup Folder Key"
                backupFolderKeyItem.target = self
                backupFolderKeyItem.action = #selector(self.backupFolderKey(_:))
                menu.addItem(backupFolderKeyItem)
                
                menu.addItem(NSMenuItem.separator())

                let removeFolderItem = NSMenuItem()
                removeFolderItem.representedObject = folder
                removeFolderItem.title = "Remove Folder"
                removeFolderItem.target = self
                removeFolderItem.action = #selector(self.removeFolder(_:))
                menu.addItem(removeFolderItem)
                
                item.menu = menu
            }
            return item
        case .dashboardInspectorItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Toggle Inspector View"
            item.paletteLabel = "Toggle Inspector View"
            item.toolTip = "Toggle Inspector View"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle Inspector View")
            return item
        case .dashboardInspectorSeparactorItem:
            if let vc = self.window?.contentViewController as? PFDashboardContainerViewController, let inspectorItem = vc.splitViewItems.last {
                if inspectorItem.isCollapsed {
                    return nil
                } else {
                    let item = NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: vc.splitView, dividerIndex: 1)
                    return item
                }
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .space,
            .flexibleSpace,
            .dashboardSidebarItem,
            .dashboardAddItem,
            .dashboardShareItem,
            .dashboardBackwardItem,
            .dashboardForwardItem,
            .dashboardReloadItem,
            .dashboardHomeItem,
            .dashboardActionItem,
            .dashboardInspectorItem
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .dashboardSidebarItem,
            .flexibleSpace,
            .dashboardAddItem,
            .dashboardSidebarSeparatorItem,
            .dashboardBackwardItem,
            .dashboardForwardItem,
            .flexibleSpace,
            .dashboardHomeItem,
            .dashboardReloadItem,
            .dashboardShareItem,
            .dashboardActionItem,
            .dashboardInspectorSeparactorItem,
            .flexibleSpace,
            .dashboardInspectorItem
        ]
    }
    
    func toolbarImmovableItemIdentifiers(_ toolbar: NSToolbar) -> Set<NSToolbarItem.Identifier> {
        return [
            .flexibleSpace,
            .dashboardAddItem,
            .dashboardSidebarItem,
            .dashboardSidebarSeparatorItem,
            .dashboardInspectorItem,
            .dashboardInspectorSeparactorItem
        ]
    }
    
    func toolbarWillAddItem(_ notification: Notification) {
    }
    
    func toolbarDidRemoveItem(_ notification: Notification) {
        debugPrint("toolbarDidRemoveItem: \(notification)")
        setupToolbar()
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // Return the identifiers you'd like to show as "selected" when clicked.
        // Similar to how they look in typical Preferences windows.
        return []
    }
}


// MARK: - Sharing Service

extension PFDashboardWindowController: NSSharingServicePickerToolbarItemDelegate {
    func items(for pickerToolbarItem: NSSharingServicePickerToolbarItem) -> [Any] {
        let serviceStore = PlanetPublishedServiceStore.shared
        guard let selectedID = serviceStore.selectedFolderID, let folder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }), let _ = folder.published, let publishedLink = folder.publishedLink, let url = URL(string: "\(IPFSDaemon.preferredGateway())/ipns/\(publishedLink)") else { return [] }
        let sharableItems = [url]
        return sharableItems
    }
}
