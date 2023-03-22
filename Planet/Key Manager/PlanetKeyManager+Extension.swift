//
//  PlanetKeyManager+Extension.swift
//  Planet
//
//  Created by Kai on 3/9/23.
//

import Foundation
import Cocoa


extension NSToolbar.Identifier {
    static let keyManagerToolbarIdentifier = NSToolbar.Identifier("PlanetKeyManagerWindowToolbar")
}


extension NSToolbarItem.Identifier {
    static let keyManagerReloadItem = NSToolbarItem.Identifier("PlanetKeyManagerToolbarReloadItem")
    static let keyManagerSyncItem = NSToolbarItem.Identifier("PlanetKeyManagerToolbarSyncItem")
    static let keyManagerImportItem = NSToolbarItem.Identifier("PlanetKeyManagerToolbarImportItem")
    static let keyManagerExportItem = NSToolbarItem.Identifier("PlanetKeyManagerToolbarExportItem")
}


extension Notification.Name {
    static let keyManagerReloadUI = Notification.Name("PlanetKeyManagerReloadUINotification")
}
