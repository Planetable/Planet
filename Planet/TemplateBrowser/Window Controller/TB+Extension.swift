//
//  TB+Extension.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import Foundation
import Cocoa


extension CGFloat {
    static let templateSidebarWidth: CGFloat = 200
    static let templateSidebarMaxWidth: CGFloat = 300
    static let templateInspectorWidth: CGFloat = 200
    static let templateInspectorMaxWidth: CGFloat = 300
    static let templateContentWidth: CGFloat = 300
}


extension Notification.Name {
    static let templateInspectorIsCollapsedStatusChanged = Notification.Name("TemplateBrowserInspectorIsCollapsedStatusChangedNotification")
}


extension String {
    static let templateContainerViewIdentifier = "TemplateBrowserContainerViewController"
}


extension NSToolbar.Identifier {
    static let templateToolbarIdentifier = NSToolbar.Identifier("TemplateBrowserWindowToolbar")
}


extension NSToolbarItem.Identifier {
    static let templateSidebarSeparatorItem = NSToolbarItem.Identifier("TemplateBrowserToolbarSidebarSeparatorItem")
    static let templateSidebarItem = NSToolbarItem.Identifier("TemplateBrowserToolbarSidebarItem")
    static let templateInspectorSeparactorItem = NSToolbarItem.Identifier("TemplateBrowserToolbarInspectorSeparatorItem")
    static let templateInspectorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarInspectorItem")
    static let reloadItem = NSToolbarItem.Identifier("TemplateBrowserToolbarReloadItem")
    static let revealItem = NSToolbarItem.Identifier("TemplateBrowserToolbarRevealItem")
    static let vsCodeItem = NSToolbarItem.Identifier("TemplateBrowserToolbarVSCodeItem")
}
