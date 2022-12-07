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
    static let templateContentWidth: CGFloat = 400
    static let templateContentHeight: CGFloat = 420
}


extension Notification.Name {
    static let templateInspectorIsCollapsedStatusChanged = Notification.Name("TemplateBrowserInspectorIsCollapsedStatusChangedNotification")
    static let templateTitleSubtitleUpdated = Notification.Name("TemplateBrowserTitleAndSubtitleUpdatedNotification")
    static let templatePreviewIndexUpdated = Notification.Name("TemplateBrowserPreviewIndexUpdatedNotification")
}


extension String {
    static let selectedTemplateID = "TemplateBrowserView.selectedTemplateID"
    static let selectedPreviewIndex = "TemplateBrowserView.selectedPreviewIndex"
    static let templateContainerViewIdentifier = "TemplateBrowserContainerViewController"
}


extension NSToolbar.Identifier {
    static let templateToolbarIdentifier = NSToolbar.Identifier("TemplateBrowserWindowToolbar")
}


extension NSToolbarItem.Identifier {
    static let templateSidebarSeparatorItem = NSToolbarItem.Identifier("TemplateBrowserToolbarSidebarSeparatorItem")
    static let templateSidebarItem = NSToolbarItem.Identifier("TemplateBrowserToolbarSidebarItem")
    static let templateInspectorSeparatorItem = NSToolbarItem.Identifier("TemplateBrowserToolbarInspectorSeparatorItem")
    static let templateInspectorItem = NSToolbarItem.Identifier("PublishedFoldersDashboardToolbarInspectorItem")
    static let templateReloadItem = NSToolbarItem.Identifier("TemplateBrowserToolbarReloadItem")
    static let templateRevealItem = NSToolbarItem.Identifier("TemplateBrowserToolbarRevealItem")
    static let templateVSCodeItem = NSToolbarItem.Identifier("TemplateBrowserToolbarVSCodeItem")
    static let templatePreviewItems = NSToolbarItem.Identifier("TemplateBrowserToolbarPreviewItemGroup")
}
