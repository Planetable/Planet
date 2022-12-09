//
//  TBContainerViewController.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import Cocoa


class TBContainerViewController: NSSplitViewController {

    lazy var sidebarViewController = TBSidebarViewController()
    lazy var contentViewController = TBContentViewController()
    lazy var inspectorViewController = TBInspectorViewController()
    
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


extension TBContainerViewController {
    private func setupViewControllers() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear

        splitView.dividerStyle = .thin
        sidebarViewController.view.widthAnchor.constraint(lessThanOrEqualToConstant: .templateSidebarMaxWidth).isActive = true
        contentViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: .templateContentWidth).isActive = true
        inspectorViewController.view.widthAnchor.constraint(lessThanOrEqualToConstant: .templateInspectorMaxWidth).isActive = true
    }

    private func setupLayout() {
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = true
        sidebarItem.titlebarSeparatorStyle = .automatic
        sidebarItem.holdingPriority = .defaultLow
        sidebarItem.allowsFullHeightLayout = true
        addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: contentViewController)
        contentItem.titlebarSeparatorStyle = .line
        addSplitViewItem(contentItem)

        let inspectorItem = NSSplitViewItem(viewController: inspectorViewController)
        inspectorItem.allowsFullHeightLayout = true
        sidebarItem.titlebarSeparatorStyle = .automatic
        inspectorItem.canCollapse = true
        inspectorItem.holdingPriority = .defaultLow
        inspectorItem.isCollapsed = UserDefaults.standard.bool(forKey: String.templateInspectorIsCollapsed)
        addSplitViewItem(inspectorItem)

        splitView.autosaveName = NSSplitView.AutosaveName(stringLiteral: String.templateContainerViewIdentifier)
        splitView.identifier = NSUserInterfaceItemIdentifier(String.templateContainerViewIdentifier)

        observer = inspectorItem.observe(\.isCollapsed, options: [.new], changeHandler: { item, _ in
            UserDefaults.standard.set(item.isCollapsed, forKey: String.templateInspectorIsCollapsed)
            let animationValue: CGFloat = item.isCollapsed ? 0.05 : 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + animationValue) {
                NotificationCenter.default.post(name: .templateInspectorIsCollapsedStatusChanged, object: nil)
            }
        })
    }
}
