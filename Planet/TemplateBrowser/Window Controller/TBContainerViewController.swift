//
//  TBContainerViewController.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import Cocoa


class TBContainerViewController: NSSplitViewController {

    lazy var sidebarViewController = TBSidebarViewController()
    lazy var viewController = TBViewController()
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
        splitView.autosaveName = NSSplitView.AutosaveName(stringLiteral: String.templateContainerViewIdentifier)
        splitView.identifier = NSUserInterfaceItemIdentifier(String.templateContainerViewIdentifier)
        
        sidebarViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: .templateSidebarWidth).isActive = true
        viewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: .templateContentWidth).isActive = true
        inspectorViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: .templateInspectorWidth).isActive = true
    }

    private func setupLayout() {
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = true
        sidebarItem.titlebarSeparatorStyle = .automatic
        sidebarItem.holdingPriority = .defaultLow
        sidebarItem.allowsFullHeightLayout = true
        addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: viewController)
        addSplitViewItem(contentItem)

        let inspectorItem = NSSplitViewItem(viewController: inspectorViewController)
        inspectorItem.allowsFullHeightLayout = true
        sidebarItem.titlebarSeparatorStyle = .automatic
        inspectorItem.canCollapse = true
        inspectorItem.holdingPriority = .defaultLow
        addSplitViewItem(inspectorItem)

        observer = inspectorItem.observe(\.isCollapsed, options: [.new], changeHandler: { item, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .templateInspectorIsCollapsedStatusChanged, object: nil)
            }
        })
    }
}
