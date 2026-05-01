//
//  PlanetDownloadsWebView.swift
//  Planet
//
//  Created by Kai on 8/3/22.
//

import Cocoa
import WebKit


class PlanetDownloadsWebView: WKWebView {
    
    init() {
        super.init(frame: CGRect(), configuration: WKWebViewConfiguration())
        DownloadsScriptMessageHandler.instance.ensureHandles(configuration: self.configuration)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        let menuItemsToHide: [NSUserInterfaceItemIdentifier] = [Self.goBackIdentifier, Self.goForwardIdentifier, Self.openFrameInNewWindowIdentifier]
        for menuItem in menu.items {
            guard let identifier = menuItem.identifier else { continue }
            if menuItemsToHide.contains(identifier) {
                menuItem.isHidden = true
                continue
            }
            switch identifier {
            case Self.openLinkIdentifier:
                menuItem.target = self
                menuItem.action = #selector(openLinkAction(_:))
                menuItem.isHidden = shouldHideSelectedMenuItem()
            case Self.openLinkInNewWindowIdentifier:
                menuItem.target = self
                menuItem.action = #selector(openLinkAction(_:))
                menuItem.isHidden = shouldHideSelectedMenuItem()
            case Self.downloadLinkedFileIdentifier:
                menuItem.target = self
                menuItem.action = #selector(downloadFileAction(_:))
                menuItem.isHidden = shouldHideSelectedMenuItem(isDownloadableTarget: true)
            case Self.openImageInNewWindowIdentifier:
                menuItem.target = self
                menuItem.action = #selector(openImageAction(_:))
                menuItem.isHidden = shouldHideSelectedMenuItem()
            case Self.downloadImageIdentifier:
                menuItem.target = self
                menuItem.action = #selector(downloadFileAction(_:))
                menuItem.isHidden = shouldHideSelectedMenuItem()
            default:
                break
            }
        }
    }
    
    private func shouldHideSelectedMenuItem(isDownloadableTarget: Bool = false) -> Bool {
        if isDownloadableTarget {
            var url: URL?
            if let _ = DownloadsScriptMessageHandler.instance.src, let href = DownloadsScriptMessageHandler.instance.href {
                url = URL(string: href)
            } else if let src = DownloadsScriptMessageHandler.instance.src {
                url = URL(string: src)
            } else if let href = DownloadsScriptMessageHandler.instance.href {
                url = URL(string: href)
            }
            if let url = url {
                return !PlanetDownloadItem.downloadableFileExtensions().contains(url.pathExtension)
            } else {
                return true
            }
        }
        return !DownloadsScriptMessageHandler.instance.hasSelectedURL
    }
    
    @objc private func openLinkAction(_ sender: NSMenuItem) {
        guard let url = DownloadsScriptMessageHandler.instance.hrefURL else { return }
        if url.isFileURL {
            ArticleWebViewModel.shared.processInternalFileLink(url)
        }
        ArticleWebViewModel.shared.processPossibleInternalLink(url)
        if !ArticleWebViewModel.shared.checkInternalLink(url) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func downloadFileAction(_ sender: NSMenuItem) {
        if let url = DownloadsScriptMessageHandler.instance.selectedSourceURL {
            self.load(URLRequest(url: url))
        }
    }
    
    @objc private func openImageAction(_ sender: NSMenuItem) {
        if let url = DownloadsScriptMessageHandler.instance.selectedSourceURL {
            NSWorkspace.shared.open(url)
        }
    }
    
}


extension PlanetDownloadsWebView {
    static let reloadIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierReload")
    static let goBackIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierGoBack")
    static let goForwardIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierGoForward")
    static let lookUpIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierLookUp")
    static let translateIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierTranslate")
    static let searchWebIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierSearchWeb")
    static let openFrameInNewWindowIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenFrameInNewWindow")
    static let openLinkIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLink")
    static let openLinkInNewWindowIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLinkInNewWindow")
    static let downloadLinkedFileIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierDownloadLinkedFile")
    static let openImageInNewWindowIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenImageInNewWindow")
    static let downloadImageIdentifier = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierDownloadImage")
}
