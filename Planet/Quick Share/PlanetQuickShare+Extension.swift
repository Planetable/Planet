//
//  PlanetQuickShare+Extension.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import Foundation


extension String {
    static let lastSelectedQuickSharePlanetID = "PlanetQuickShare.lastSelectedPlanetID"
}


extension Notification.Name {
    static let cancelQuickShare = Notification.Name("PlanetQuickShareCancelNotification")
}
