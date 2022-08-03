//
//  PlanetDownloadsWebView.swift
//  Planet
//
//  Created by Kai on 8/3/22.
//

import Cocoa
import WebKit


class PlanetDownloadsWebView: WKWebView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        for menuItem in menu.items {
            guard let identifier = menuItem.identifier else { continue }
            switch identifier {
            case Self.openLinkIdentifier:
                debugPrint("open link")
            case Self.openLinkInNewWindowIdentifier:
                debugPrint("open link in new window")
            case Self.downloadLinkedFileIdentifier:
                debugPrint("download linked file")
            case Self.openImageInNewWindowIdentifier:
                debugPrint("open image in new window")
            case Self.downloadImageIdentifier:
                debugPrint("download image")
            default:
                break
            }
        }
    }

}


extension PlanetDownloadsWebView {
    static let openLinkIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLink")
    static let openLinkInNewWindowIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLinkInNewWindow")
    static let downloadLinkedFileIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierDownloadLinkedFile")
    static let openImageInNewWindowIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenImageInNewWindow")
    static let downloadImageIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierDownloadImage")
}
