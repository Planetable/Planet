//
//  AppWindowController.swift
//  PlanetLite
//

import Cocoa


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
        self.window?.setFrameAutosaveName(.appName + " Window")
//        NotificationCenter.default.addObserver(forName: .dashboardInspectorIsCollapsedStatusChanged, object: nil, queue: .main) { [weak self] _ in
//            self?.setupToolbar()
//        }
//        NotificationCenter.default.addObserver(forName: .dashboardRefreshToolbar, object: nil, queue: .main) { [weak self] _ in
//            self?.setupToolbar()
//        }
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
//        NotificationCenter.default.removeObserver(self, name: .dashboardInspectorIsCollapsedStatusChanged, object: nil)
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
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
        case .sidebarItem:
            if let vc = self.window?.contentViewController as? AppContainerViewController {
                vc.toggleSidebar(sender)
            }
        case .addItem:
            newArticle()
        case .showInfoItem:
            showPlanetInfo()
        default:
            break
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
        case .showInfoItem:
            if case .myPlanet(_) = PlanetStore.shared.selectedView {
                return true
            }
            return false
        default:
            return false
        }
    }
}


extension AppWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
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
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .sidebarItem,
            .sidebarSeparatorItem,
            .flexibleSpace,
            .showInfoItem,
            .addItem
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .sidebarItem,
            .sidebarSeparatorItem,
            .flexibleSpace,
            .showInfoItem,
            .addItem
        ]
    }
    
    func toolbarImmovableItemIdentifiers(_ toolbar: NSToolbar) -> Set<NSToolbarItem.Identifier> {
        return [
            .sidebarItem,
            .sidebarSeparatorItem,
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
