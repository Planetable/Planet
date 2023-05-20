//
//  AppContainerViewController.swift
//  PlanetLite
//

import Cocoa


class AppContainerViewController: NSSplitViewController {
    
    lazy var sidebarViewController = AppSidebarViewController()
    lazy var contentViewController = AppContentViewController()

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


extension AppContainerViewController {
    private func setupViewControllers() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        splitView.dividerStyle = .thin
        sidebarViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: AppUI.WINDOW_SIDEBAR_WIDTH_MIN).isActive = true
        contentViewController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: AppUI.WINDOW_CONTENT_WIDTH_MIN).isActive = true
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
        
        self.splitView.autosaveName = NSSplitView.AutosaveName(stringLiteral: String.containerViewIdentifier)
        self.splitView.identifier = NSUserInterfaceItemIdentifier(String.containerViewIdentifier)

        observer = sidebarItem.observe(\.isCollapsed, options: [.new], changeHandler: { item, _ in
            debugPrint("App sidebar is collapsed: \(item.isCollapsed)")
            /*
            UserDefaults.standard.set(item.isCollapsed, forKey: String.sidebarIsCollapsed)
            let animationValue: CGFloat = item.isCollapsed ? 0.05 : 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + animationValue) {
                NotificationCenter.default.post(name: .dashboardInspectorIsCollapsedStatusChanged, object: nil)
            }
             */
        })
    }
}
