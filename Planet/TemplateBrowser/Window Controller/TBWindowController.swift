//
//  TBWindowController.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import Cocoa


class TBWindowController: NSWindowController {

    override init(window: NSWindow?) {
        let windowSize = NSSize(width: .templateSidebarWidth + .templateContentWidth + .templateInspectorWidth, height: 320)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = TBWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView, .unifiedTitleAndToolbar], backing: .buffered, defer: true)
        w.minSize = windowSize
        w.toolbarStyle = .unified
        super.init(window: w)
        self.setupToolbar()
        self.window?.setFrameAutosaveName("Template Browser Window")
        NotificationCenter.default.addObserver(forName: .templateInspectorIsCollapsedStatusChanged, object: nil, queue: .main) { _ in
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
        let toolbar = NSToolbar(identifier: .templateToolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        w.title = "Template Browser"
        w.toolbar = toolbar
        w.toolbar?.validateVisibleItems()
    }
    
    @objc func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
            case .templateSidebarItem:
                if let vc = self.window?.contentViewController as? TBContainerViewController {
                    vc.toggleSidebar(sender)
                }
            default:
                break
        }
    }
}


// MARK: - Toolbar Validation

extension TBWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .templateSidebarItem:
            return true
        default:
            return false
        }
    }
}


// MARK: - Toolbar Delegate

extension TBWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .templateSidebarItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.target = self
            item.action = #selector(self.toolbarItemAction(_:))
            item.label = "Toggle Sidebar"
            item.paletteLabel = "Toggle Sidebar"
            item.toolTip = "Toggle Sidebar"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            return item
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .space,
            .flexibleSpace,
            .templateSidebarItem
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .templateSidebarItem,
            .flexibleSpace,
            .templateSidebarSeparatorItem,
            .flexibleSpace
        ]
    }

    func toolbarImmovableItemIdentifiers(_ toolbar: NSToolbar) -> Set<NSToolbarItem.Identifier> {
        return [
            .templateSidebarItem
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
