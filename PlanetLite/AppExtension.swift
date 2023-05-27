//
//  AppExtension.swift
//  PlanetLite
//

import Cocoa


extension String {
    static let containerViewIdentifier = "AppContainerViewController"
}


extension NSToolbar.Identifier {
    static let toolbarIdentifier = NSToolbar.Identifier("PlanetLiteWindowToolbar")
}


extension NSToolbarItem.Identifier {
    static let sidebarSeparatorItem = NSToolbarItem.Identifier("PlanetLiteToolbarSidebarSeparatorItem")
    static let sidebarItem = NSToolbarItem.Identifier("PlanetLiteToolbarSidebarItem")
    static let addItem = NSToolbarItem.Identifier("PlanetLiteToolbarAddItem")
    static let showInfoItem = NSToolbarItem.Identifier("PlanetLiteToolbarShowInfoItem")
}
