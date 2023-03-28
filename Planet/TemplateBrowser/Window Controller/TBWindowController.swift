//
//  TBWindowController.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import Cocoa


class TBWindowController: NSWindowController {

    override init(window: NSWindow?) {
        let windowSize = NSSize(width: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN + PlanetUI.WINDOW_CONTENT_WIDTH_MIN + PlanetUI.WINDOW_INSPECTOR_WIDTH_MIN, height: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = TBWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView, .unifiedTitleAndToolbar], backing: .buffered, defer: true)
        w.minSize = windowSize
        w.maxSize = NSSize(width: screenSize.width, height: .infinity)
        w.toolbarStyle = .unified
        super.init(window: w)
        self.setupToolbar()
        self.updateTemplateWindowTitles()
        self.window?.setFrameAutosaveName("Template Browser Window")
        NotificationCenter.default.addObserver(forName: .templateInspectorIsCollapsedStatusChanged, object: nil, queue: .main) { [weak self] _ in
            self?.setupToolbar()
        }
        NotificationCenter.default.addObserver(forName: .templateTitleSubtitleUpdated, object: nil, queue: .main) { [weak self] _ in
            self?.updateTemplateWindowTitles()
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .templateInspectorIsCollapsedStatusChanged, object: nil)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    private func setupToolbar() {
        guard let w = self.window else { return }
        let toolbar = NSToolbar(identifier: .templateToolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        if #available(macOS 13.0, *) {
            toolbar.centeredItemIdentifiers = [.templatePreviewItems]
        }
        w.title = "Template Browser"
        w.toolbar = toolbar
        w.toolbar?.validateVisibleItems()
    }

    private func hasVSCode() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil
    }

    private func openVSCode() {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
        else { return }
        guard let templateID = TemplateStore.shared.selectedTemplateID, let template = TemplateStore.shared.templates.first(where: { $0.id == templateID }) else { return }

        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: self.openConfiguration(), completionHandler: nil)
    }

    private func openConfiguration() -> NSWorkspace.OpenConfiguration {
        let conf = NSWorkspace.OpenConfiguration()
        conf.hidesOthers = false
        conf.hides = false
        conf.activates = true
        return conf
    }

    private func revealInFinder() {
        guard let templateID = TemplateStore.shared.selectedTemplateID, let template = TemplateStore.shared.templates.first(where: { $0.id == templateID }) else { return }
        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func refresh() {
        NotificationCenter.default.post(name: .refreshTemplatePreview, object: nil)
    }

    private func updateTemplateWindowTitles() {
        guard let templateID = TemplateStore.shared.selectedTemplateID, let template = TemplateStore.shared.templates.first(where: { $0.id == templateID }) else {
            self.window?.title = "Template Browser"
            self.window?.subtitle = ""
            return
        }
        self.window?.title = "\(template.name)"
        self.window?.subtitle = "\(template.author) · Version \(template.version)"
    }

    @objc private func toolbarItemAction(_ sender: Any) {
        guard let item = sender as? NSToolbarItem else { return }
        switch item.itemIdentifier {
            case .templateSidebarItem:
                if let vc = self.window?.contentViewController as? TBContainerViewController {
                    vc.toggleSidebar(sender)
                }
            case .templateInspectorItem:
                if let vc = self.window?.contentViewController as? TBContainerViewController, let inspectorItem = vc.splitViewItems.last {
                    inspectorItem.animator().isCollapsed.toggle()
                    UserDefaults.standard.set(inspectorItem.isCollapsed, forKey: String.templateInspectorIsCollapsed)
                }
            case .templateReloadItem:
                refresh()
            case .templateRevealItem:
                revealInFinder()
            case .templateVSCodeItem:
                openVSCode()
            case .templatePreviewItems:
                if let itemGroup = sender as? NSToolbarItemGroup {
                    NotificationCenter.default.post(name: .templatePreviewIndexUpdated, object: NSNumber(integerLiteral: itemGroup.selectedIndex))
                    UserDefaults.standard.set(itemGroup.selectedIndex, forKey: String.selectedPreviewIndex)
                }
            default:
                break
        }
    }
}


// MARK: - Toolbar Validation

extension TBWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        let templateSelected: Bool = TemplateStore.shared.selectedTemplateID != nil
        switch item.itemIdentifier {
            case .templateSidebarItem:
                return true
            case .templateSidebarSeparatorItem:
                return true
            case .templateInspectorItem:
                return true
            case .templateInspectorSeparatorItem:
                return true
            case .templatePreviewItems:
                return true
            case .templateReloadItem:
                return templateSelected
            case .templateVSCodeItem:
                return self.hasVSCode() && templateSelected
            case .templateRevealItem:
                return templateSelected
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
            case .templateSidebarSeparatorItem:
                if let vc = self.window?.contentViewController as? TBContainerViewController {
                    let item = NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: vc.splitView, dividerIndex: 0)
                    return item
                } else {
                    return nil
                }
            case .templateInspectorItem:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.target = self
                item.action = #selector(self.toolbarItemAction(_:))
                item.label = "Toggle Inspector View"
                item.paletteLabel = "Toggle Inspector View"
                item.toolTip = "Toggle Inspector View"
                item.isBordered = true
                item.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle Inspector View")
                return item
            case .templateInspectorSeparatorItem:
                if let vc = self.window?.contentViewController as? TBContainerViewController, let inspectorItem = vc.splitViewItems.last {
                    if inspectorItem.isCollapsed {
                        return nil
                    } else {
                        let item = NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: vc.splitView, dividerIndex: 1)
                        return item
                    }
                } else {
                    return nil
                }
            case .templateVSCodeItem:
                if self.hasVSCode() {
                    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                    item.target = self
                    item.action = #selector(self.toolbarItemAction(_:))
                    item.label = "Open in VSCode"
                    item.paletteLabel = "Open in VSCode"
                    item.toolTip = "Open in VSCode"
                    item.isBordered = true
                    item.image = NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: "Open in VSCode")
                    return item
                } else {
                    return nil
                }
            case .templateReloadItem:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.target = self
                item.action = #selector(self.toolbarItemAction(_:))
                item.label = "Refresh"
                item.paletteLabel = "Refresh Template"
                item.toolTip = "Refresh Template"
                item.isBordered = true
                item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh Template")
                return item
            case .templateRevealItem:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.target = self
                item.action = #selector(self.toolbarItemAction(_:))
                item.label = "Reveal in Finder"
                item.paletteLabel = "Reveal in Finder"
                item.toolTip = "Reveal in Finder"
                item.isBordered = true
                item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Reveal in Finder")
                return item
            case .templatePreviewItems:
                guard
                    let indexImage: NSImage = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "Index"),
                    let blogImage: NSImage = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "Blog")
                else {
                    return nil
                }
                let item = NSToolbarItemGroup(itemIdentifier: itemIdentifier, images: [blogImage, indexImage], selectionMode: .selectOne, labels: ["Blog", "Index"], target: self, action: #selector(self.toolbarItemAction(_:)))
                item.controlRepresentation = .automatic
                item.selectionMode = .selectOne
                item.label = "Preview Mode"
                item.paletteLabel = "Preview Mode"
                item.toolTip = "Toggle Preview Mode"
                item.selectedIndex = UserDefaults.standard.integer(forKey: String.selectedPreviewIndex)
                return item
            default:
                return nil
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .space,
            .flexibleSpace,
            .templateSidebarItem,
            .templateInspectorItem,
            .templatePreviewItems,
            .templateVSCodeItem,
            .templateRevealItem,
            .templateReloadItem
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .templateSidebarItem,
            .flexibleSpace,
            .templateSidebarSeparatorItem,
            .flexibleSpace,
            .templatePreviewItems,
            .flexibleSpace,
            .templateVSCodeItem,
            .templateRevealItem,
            .templateReloadItem,
            .templateInspectorSeparatorItem,
            .flexibleSpace,
            .templateInspectorItem
        ]
    }

    func toolbarImmovableItemIdentifiers(_ toolbar: NSToolbar) -> Set<NSToolbarItem.Identifier> {
        return [
            .flexibleSpace,
            .templateSidebarItem,
            .templateInspectorItem
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
