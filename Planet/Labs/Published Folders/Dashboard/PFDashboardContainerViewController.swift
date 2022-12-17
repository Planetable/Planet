//
//  PFDashboardContainerViewController.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import Cocoa


class PFDashboardContainerViewController: NSSplitViewController {

    lazy var sidebarViewController = PFDashboardSidebarViewController()
    lazy var contentViewController = PFDashboardViewController()
    lazy var inspectorViewController = PFDashboardInspectorViewController()

    private var observer: NSKeyValueObservation?

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupViewControllers()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        observer?.invalidate()
        observer = nil
    }
}


extension PFDashboardContainerViewController {
    private func setupViewControllers() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        
        splitView.dividerStyle = .thin

        sidebarViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: .sidebarWidth).isActive = true
        contentViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: .contentWidth).isActive = true
        inspectorViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: .inspectorWidth).isActive = true
    }

    private func setupLayout() {
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = true
        sidebarItem.titlebarSeparatorStyle = .automatic
        sidebarItem.holdingPriority = .defaultLow
        sidebarItem.allowsFullHeightLayout = true
        self.addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: contentViewController)
        self.addSplitViewItem(contentItem)

        let inspectorItem = NSSplitViewItem(viewController: inspectorViewController)
        inspectorItem.allowsFullHeightLayout = true
        sidebarItem.titlebarSeparatorStyle = .automatic
        inspectorItem.canCollapse = true
        inspectorItem.holdingPriority = .defaultLow
        self.addSplitViewItem(inspectorItem)

        self.splitView.autosaveName = NSSplitView.AutosaveName(stringLiteral: String.dashboardContainerViewIdentifier)
        self.splitView.identifier = NSUserInterfaceItemIdentifier(String.dashboardContainerViewIdentifier)

        observer = inspectorItem.observe(\.isCollapsed, options: [.new], changeHandler: { item, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .dashboardInspectorIsCollapsedStatusChanged, object: nil)
            }
        })
    }
}
