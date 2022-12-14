//
//  PublishedFolders+Extension.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import Cocoa


extension CGFloat {
    static let sidebarWidth: CGFloat = 200
    static let inspectorWidth: CGFloat = 200
    static let contentWidth: CGFloat = 300
}

extension Notification.Name {
    static let dashboardInspectorIsCollapsedStatusChanged = Notification.Name("PublishedFoldersDashboardInspectorIsCollapsedStatusChangedNotification")
}


extension String {
    static let dashboardContainerViewIdentifier = "PublishedFoldersDashboardContainerViewController"
    static let settingsShowAccessoryStatusView = "PublishedFoldersDashboardShowAccessoryStatusView"
}


extension NSToolbar.Identifier {
    static let dashboardToolbarIdentifier = NSToolbar.Identifier("PublishedFoldersDashboardWindowToolbar")
}


extension NSToolbarItem.Identifier {
    static let dashboardAccessoryStatusViewItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarAccessoryStatusViewItem")
    static let dashboardSidebarSeparatorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarSidebarSeparatorItem")
    static let dashboardSidebarItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarSidebarItem")
    static let dashboardInspectorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarInspectorItem")
    static let dashboardInspectorSeparactorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarInspectorSeparatorItem")
    static let dashboardAddItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarAddItem")
    static let dashboardShareItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarShareItem")
    static let dashboardSearchItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarSearchItem")
}
