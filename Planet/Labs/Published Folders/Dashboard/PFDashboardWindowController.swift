//
//  PFDashboardWindowController.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import Cocoa


class PFDashboardWindowController: NSWindowController {

    private var accessoryStatusViewController: PFDashboardAccessoryStatusViewController?
    private var accessoryStatusViewButton: NSToolbarItem?
    private var accessoryStatusViewIsHidden: Bool = UserDefaults.standard.bool(forKey: String.settingsShowAccessoryStatusView) {
        didSet {
            UserDefaults.standard.set(accessoryStatusViewIsHidden, forKey: String.settingsShowAccessoryStatusView)
        }
    }

    override init(window: NSWindow?) {
        let windowSize = NSSize(width: .sidebarWidth + .contentWidth + .inspectorWidth, height: 320)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = PFDashboardWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView, .unifiedTitleAndToolbar], backing: .buffered, defer: true)
        w.minSize = windowSize
        w.toolbarStyle = .unified
        super.init(window: w)
        self.setupToolbar()
        self.setupAccessoryStatusView()
        self.window?.setFrameAutosaveName("Published Folders Dashboard Window")
        NotificationCenter.default.addObserver(forName: .dashboardInspectorIsCollapsedStatusChanged, object: nil, queue: .main) { _ in
            self.setupToolbar()
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    private func setupToolbar() {
        guard let w = self.window else { return }
        let toolbar = NSToolbar(identifier: .dashboardToolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        w.title = "Published Folders Dashboard"
        w.toolbar = toolbar
        w.toolbar?.validateVisibleItems()
    }

    @objc func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
            case .dashboardSidebarItem:
                if let vc = self.window?.contentViewController as? PFDashboardContainerViewController {
                    vc.toggleSidebar(sender)
                }
            case .dashboardAddItem:
                break
            case .dashboardShareItem:
                break
            case .dashboardSearchItem:
                break
            case .dashboardInspectorItem:
                if let vc = self.window?.contentViewController as? PFDashboardContainerViewController, let inspectorItem = vc.splitViewItems.last {
                    inspectorItem.animator().isCollapsed.toggle()
                }
            case .dashboardAccessoryStatusViewItem:
                self.toggleAccessoryStatusView()
            default:
                break
        }
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
            case .dashboardSidebarItem:
                return true
            case .dashboardAccessoryStatusViewItem:
                return self.accessoryStatusViewController != nil
            case .dashboardSearchItem:
                return true
            case .dashboardInspectorItem:
                return true
            default:
                return false    // disabled
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
            case .dashboardAccessoryStatusViewItem:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.target = self
                item.action = #selector(self.toolbarItemAction(_:))
                item.label = self.accessoryStatusViewIsHidden ? "Show" : "Hide"
                item.paletteLabel = "Toggle Status View"
                item.toolTip = self.accessoryStatusViewIsHidden ? "Show Status View" : "Hide Status View"
                item.isBordered = true
                item.image = NSImage(systemSymbolName: self.accessoryStatusViewIsHidden ? "info.circle" : "info.circle.fill", accessibilityDescription: "Toggle Status View")
//                if #available(macOS 13.0, *) {
//                    item.possibleLabels = ["Show", "Hide"]
//                }
                self.accessoryStatusViewButton = item
                return item
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
            case .dashboardSearchItem:
                let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
                item.resignsFirstResponderWithCancel = true
                item.searchField.delegate = self
                item.toolTip = "Search"
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
            .dashboardSearchItem,
            .dashboardAccessoryStatusViewItem,
            .dashboardInspectorItem
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .dashboardSidebarItem,
            .flexibleSpace,
            .dashboardAddItem,
            .dashboardSidebarSeparatorItem,
            .flexibleSpace,
            .dashboardShareItem,
            .dashboardSearchItem,
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


// MARK: - Titlebar Accessory Status View

extension PFDashboardWindowController {
    private func setupAccessoryStatusView() {
        let controller = PFDashboardAccessoryStatusViewController()
        controller.layoutAttribute = .bottom
        controller.fullScreenMinHeight = controller.view.bounds.height
        self.window?.addTitlebarAccessoryViewController(controller)
        self.accessoryStatusViewController = controller
        self.accessoryStatusViewController?.isHidden = self.accessoryStatusViewIsHidden
    }

    func toggleAccessoryStatusView() {
        self.accessoryStatusViewIsHidden.toggle()
        self.accessoryStatusViewController?.isHidden = self.accessoryStatusViewIsHidden
        switch self.accessoryStatusViewIsHidden {
            case true:
                self.accessoryStatusViewButton?.label = "Show"
                self.accessoryStatusViewButton?.toolTip = "Show Published Folders Status"
                self.accessoryStatusViewButton?.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Show Published Folders Status")
            default:
                self.accessoryStatusViewButton?.label = "Hide"
                self.accessoryStatusViewButton?.toolTip = "Hide Published Folders Status"
                self.accessoryStatusViewButton?.image = NSImage(systemSymbolName: "info.circle.fill", accessibilityDescription: "Hide Published Folders Status")
        }
    }
}


// MARK: - Sharing Service

extension PFDashboardWindowController: NSSharingServicePickerToolbarItemDelegate {
    func items(for pickerToolbarItem: NSSharingServicePickerToolbarItem) -> [Any] {
        let sharableItems = [URL(string: "https://www.apple.com/")!]
        return sharableItems
    }
}


// MARK: - Search Field

extension PFDashboardWindowController: NSSearchFieldDelegate {
    func searchFieldDidStartSearching(_ sender: NSSearchField) {
        debugPrint("search field did start: \(sender.stringValue)")
    }

    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        debugPrint("search field did end: \(sender.stringValue)")
        let _ = sender.resignFirstResponder()
    }
}
