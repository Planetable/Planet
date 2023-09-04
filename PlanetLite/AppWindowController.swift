//
//  AppWindowController.swift
//  PlanetLite
//

import Cocoa
import SwiftUI


class AppWindowController: NSWindowController {

    override init(window: NSWindow?) {
        let windowSize = NSSize(width: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN + PlanetUI.WINDOW_CONTENT_WIDTH_MIN, height: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = AppWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView, .unifiedTitleAndToolbar], backing: .buffered, defer: true)
        w.minSize = windowSize
        w.maxSize = NSSize(width: screenSize.width, height: .infinity)
        w.toolbarStyle = .unified
        super.init(window: w)
        self.setupToolbar()
        self.window?.setFrameAutosaveName(.liteAppName + " Window")
        NotificationCenter.default.addObserver(forName: .updatePlanetLiteWindowTitles, object: nil, queue: .main) { [weak self] n in
            guard let titles = n.object as? [String: String] else { return }
            if let theTitle = titles["title"], theTitle != "" {
                self?.window?.title = theTitle
            }
            if let theSubtitle = titles["subtitle"], theSubtitle != "" {
                self?.window?.subtitle = theSubtitle
            } else {
                self?.window?.subtitle = ""
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    private func setupToolbar() {
        guard let w = self.window else { return }
        let toolbar = NSToolbar(identifier: .toolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        w.toolbar = toolbar
        w.toolbar?.validateVisibleItems()
    }

    @objc func toolbarItemAction(_ sender: Any) {
        if let item = sender as? NSMenuItem, let identifier = item.identifier {
            switch identifier {
            case .copyURLItem:
                copyURL()
            case .copyIPNSItem:
                copyIPNS()
            default:
                break
            }
        } else if let item = sender as? NSToolbarItem {
            switch item.itemIdentifier {
            case .sidebarItem:
                if let vc = self.window?.contentViewController as? AppContainerViewController {
                    vc.toggleSidebar(sender)
                }
            case .addItem:
                newArticle()
            case .showInfoItem:
                showPlanetInfo()
            case .shareItem:
                sharePlanet(sender)
            default:
                break
            }
        }
    }
}


extension AppWindowController {
    func newArticle() {
        switch PlanetStore.shared.selectedView {
        case .myPlanet(let planet):
            Task { @MainActor in
                PlanetQuickShareViewModel.shared.myPlanets = PlanetStore.shared.myPlanets
                PlanetQuickShareViewModel.shared.selectedPlanetID = planet.id
                PlanetStore.shared.isQuickSharing = true
            }
        default:
            break
        }
    }

    func showPlanetInfo() {
        guard PlanetStore.shared.isShowingPlanetInfo == false else { return }
        PlanetStore.shared.isShowingPlanetInfo = true
    }

    func sharePlanet(_ sender: Any) {
        if case .myPlanet(let planet) = PlanetStore.shared.selectedView, let toolbarItem = sender as? NSToolbarItem, let itemView = toolbarItem.value(forKey: "_itemViewer") as? NSView {
            let sharingItems: [URL] = [URL(string: "planet://\(planet.ipns)")!]
            let picker = NSSharingServicePicker(items: sharingItems)
            picker.delegate = self
            picker.show(relativeTo: itemView.bounds, of: itemView, preferredEdge: .minY)
        }
    }

    func copyURL() {
        if case .myPlanet(let planet) = PlanetStore.shared.selectedView {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("planet://\(planet.ipns)", forType: .string)
        }
    }

    func copyIPNS() {
        if case .myPlanet(let planet) = PlanetStore.shared.selectedView {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(planet.ipns, forType: .string)
        }
    }
}


extension AppWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .addItem:
            if case .myPlanet(_) = PlanetStore.shared.selectedView {
                return true
            }
            return false
        case .sidebarItem:
            return true
        case .titlebarItem:
            return true
        case .showInfoItem:
            if case .myPlanet(_) = PlanetStore.shared.selectedView {
                return true
            }
            return false
        case .shareItem:
            if case .myPlanet(_) = PlanetStore.shared.selectedView {
                return true
            }
            return false
        case .actionItem:
            if case .myPlanet(_) = PlanetStore.shared.selectedView {
                return true
            }
            return false
        default:
            return false
        }
    }
}


extension AppWindowController: NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        guard let image = NSImage(systemSymbolName: "link", accessibilityDescription: "Link") else {
            return proposedServices
        }
        var share = proposedServices
        let copyService = NSSharingService(title: "Copy Link", image: image, alternateImage: image) {
            if let item = items.first as? URL {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.absoluteString, forType: .string)
            }
        }
        share.insert(copyService, at: 0)
        return share
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        sharingServicePicker.delegate = nil
    }
}


extension AppWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .titlebarItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            let windowWidth = self.window?.frame.size.width ?? 200
            let width = windowWidth == 200 ? windowWidth : windowWidth / 3.0
            let size = CGSize(width: width, height: 52)
            let vc = AppTitlebarViewController(withSize: size)
            vc.view.frame = CGRect(origin: .zero, size: size)
            item.view = vc.view
            return item
        case .sidebarItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Toggle Sidebar"
            item.paletteLabel = "Toggle Sidebar"
            item.toolTip = "Toggle Sidebar"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            return item
        case .sidebarSeparatorItem:
            if let vc = self.window?.contentViewController as? AppContainerViewController {
                let item = NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: vc.splitView, dividerIndex: 0)
                return item
            } else {
                return nil
            }
        case .addItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "New"
            item.paletteLabel = "New Article"
            item.toolTip = "New Article"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Article")
            return item
        case .showInfoItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Info"
            item.paletteLabel = "Show Info"
            item.toolTip = "Show Info"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Show Info")
            return item
        case .shareItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Share"
            item.paletteLabel = "Share"
            item.toolTip = "Share"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
            return item
        case .actionItem:
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.menu = self.actionItemMenu()
            item.showsIndicator = true
            item.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Action")
            item.isBordered = true
            item.toolTip = "Action"
            item.label = "Action"
            item.paletteLabel = "Action"
            return item
        default:
            return nil
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .sidebarItem,
            .sidebarSeparatorItem,
            .titlebarItem,
            .flexibleSpace,
            .actionItem,
            .shareItem,
            .showInfoItem,
            .addItem
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .sidebarItem,
            .sidebarSeparatorItem,
            .titlebarItem,
            .flexibleSpace,
            .actionItem,
            .shareItem,
            .showInfoItem,
            .addItem
        ]
    }

    func toolbarImmovableItemIdentifiers(_ toolbar: NSToolbar) -> Set<NSToolbarItem.Identifier> {
        return [
            .sidebarItem,
            .sidebarSeparatorItem,
            .titlebarItem,
            .actionItem,
            .shareItem,
            .showInfoItem,
            .addItem
        ]
    }

    func toolbarDidRemoveItem(_ notification: Notification) {
        setupToolbar()
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }

}


extension AppWindowController {
    func actionItemMenu() -> NSMenu {
        let menu = NSMenu()

        /*
        let copyURLItem = NSMenuItem(title: "Copy URL", action: #selector(self.toolbarItemAction(_:)), keyEquivalent: "")
        copyURLItem.identifier = .copyURLItem
        copyURLItem.target = self
        menu.addItem(copyURLItem)
        */

        let copyIPNSItem = NSMenuItem(title: "Copy IPNS", action: #selector(self.toolbarItemAction(_:)), keyEquivalent: "")
        copyIPNSItem.identifier = .copyIPNSItem
        copyIPNSItem.target = self
        menu.addItem(copyIPNSItem)

        return menu
    }
}


extension NSToolbar.Identifier {
    static let toolbarIdentifier = NSToolbar.Identifier("PlanetLiteWindowToolbar")
}


extension NSToolbarItem.Identifier {
    static let sidebarSeparatorItem = NSToolbarItem.Identifier("PlanetLiteToolbarSidebarSeparatorItem")
    static let sidebarItem = NSToolbarItem.Identifier("PlanetLiteToolbarSidebarItem")
    static let titlebarItem = NSToolbarItem.Identifier("PlanetLiteToolbarTitlebarItem")
    static let addItem = NSToolbarItem.Identifier("PlanetLiteToolbarAddItem")
    static let showInfoItem = NSToolbarItem.Identifier("PlanetLiteToolbarShowInfoItem")
    static let shareItem = NSToolbarItem.Identifier("PlanetLiteToolbarShareItem")
    static let actionItem = NSToolbarItem.Identifier("PlanetLiteToolbarActionItem")
}


extension NSUserInterfaceItemIdentifier {
    static let copyURLItem = NSUserInterfaceItemIdentifier("PlanetLiteToolbarMenuCopyURLItem")
    static let copyIPNSItem = NSUserInterfaceItemIdentifier("PlanetLiteToolbarMenuCopyIPNSItem")
}
