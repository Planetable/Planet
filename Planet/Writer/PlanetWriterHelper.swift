//
//  PlanetWriterHelper.swift
//  Planet
//
//  Created by Kai on 3/29/22.
//

import Foundation


extension Notification.Name {
    static let clearText = Notification.Name("PlanetWriterDemoClearTextNotification")
    static let insertText = Notification.Name("PlanetWriterDemoInsertTextNotification")
    static let moveCursorFront = Notification.Name("PlanetWriterDemoMoveCursorFrontNotification")
    static let moveCursorEnd = Notification.Name("PlanetWriterDemoMoveCursorEndNotification")
    static let reloadPage = Notification.Name("PlanetWriterReloadWebpageAtPathNotification")
    static let scrollPage = Notification.Name("PlanetWriterUpdateWebpatePositionNotification")
    static func notification(notification: Notification.Name, forID id: UUID) -> Notification.Name {
        return Notification.Name(notification.rawValue + "-" + id.uuidString)
    }
}
