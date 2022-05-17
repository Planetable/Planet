//
//  PlanetWriterHelper.swift
//  Planet
//
//  Created by Kai on 3/29/22.
//

import Foundation


extension Notification.Name {
    static let clearText = Notification.Name("PlanetWriterClearTextNotification")
    static let insertText = Notification.Name("PlanetWriterInsertTextNotification")
    static let removeText = Notification.Name("PlanetWriterRemoveTextNotification")
    static let moveCursorFront = Notification.Name("PlanetWriterMoveCursorFrontNotification")
    static let moveCursorEnd = Notification.Name("PlanetWriterMoveCursorEndNotification")
    static let reloadPage = Notification.Name("PlanetWriterReloadWebpageAtPathNotification")
    static let scrollPage = Notification.Name("PlanetWriterUpdateWebpatePositionNotification")
    static let pauseMedia = Notification.Name("PlanetWriterPauseMediaNotification")
    static func notification(notification: Notification.Name, forID id: UUID) -> Notification.Name {
        return Notification.Name(notification.rawValue + "-" + id.uuidString)
    }
}
