//
//  PublishedFolders+Extension.swift
//  PublishedFoldersDashboard
//
//  Created by Kai on 11/25/22.
//

import Cocoa


extension Notification.Name {
    static let dashboardInspectorIsCollapsedStatusChanged = Notification.Name("PublishedFoldersDashboardInspectorIsCollapsedStatusChangedNotification")
    static let dashboardRefreshToolbar = Notification.Name("PublishedFoldersDashboardRefreshToolbarNotification")
    static let dashboardUpdateWindowTitles = Notification.Name("PublishedFoldersDashboardUpdateWindowTitlesNotification")
    static let dashboardLoadPreviewURL = Notification.Name("PublishedFoldersDashboardLoadPreviewURLNotification")
    static let dashboardProcessDirectoryURL = Notification.Name("PublishedFoldersDabhaordProcessDirectoryURLNotification")
    static let dashboardResetWebViewHistory = Notification.Name("PublishedFoldersDashboardResetWebViewHistoryNotification")
    static let dashboardReloadWebView = Notification.Name("PublishedFoldersDashboardReloadWebViewNotification")
    static let dashboardWebViewGoHome = Notification.Name("PublishedFoldersDashboardWebViewGoHomeNotification")
    static let dashboardWebViewGoBackward = Notification.Name("PublishedFoldersDashboardWebViewGoBackwardNotification")
    static let dashboardWebViewGoForward = Notification.Name("PublishedFoldersDashboardWebViewGoForwardNotification")
}


extension String {
    static let folderPrefixKey = "PlanetPublishedFolder-"
    static let folderPendingPrefixKey = "PlanetPublishedFolderPendingFolder-"
    static let folderRemovedListKey = "PlanetPublishedFolderRemovalList"
    static let folderAutoPublishOptionKey = "PlanetPublishedFolderAutoPublish"
    static let dashboardContainerViewIdentifier = "PublishedFoldersDashboardContainerViewController"
    static let dashboardInspectorIsCollapsed = "PublishedFoldersDashboardInspectorIsCollapsed"
    static let selectedPublishedFolderID = "PublishedFoldersDashboardSelectedFolderID"
}


extension NSToolbar.Identifier {
    static let dashboardToolbarIdentifier = NSToolbar.Identifier("PublishedFoldersDashboardWindowToolbar")
}


extension NSToolbarItem.Identifier {
    static let dashboardSidebarSeparatorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarSidebarSeparatorItem")
    static let dashboardSidebarItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarSidebarItem")
    static let dashboardInspectorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarInspectorItem")
    static let dashboardInspectorSeparactorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarInspectorSeparatorItem")
    static let dashboardAddItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarAddItem")
    static let dashboardShareItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarShareItem")
    static let dashboardActionItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarActionItem")
    static let dashboardBackwardItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarBackwardItem")
    static let dashboardForwardItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarForwardItem")
    static let dashboardReloadItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarReloadItem")
    static let dashboardHomeItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarHomeItem")
}
