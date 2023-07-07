//
//  PlanetQuickShare+Extension.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import Foundation


extension CGFloat {
    static let sheetWidth: CGFloat = 480
    static let sheetHeight: CGFloat = 380
}


extension String {
    static let lastSelectedQuickSharePlanetID = "PlanetQuickShare.lastSelectedPlanetID"
}


extension Notification.Name {
    static let updatePlanetLiteWindowTitles = Notification.Name("PlanetLiteUpdateWindowTitlesNotification")
}
