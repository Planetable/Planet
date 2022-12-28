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
        return DownloadsScriptMessageHandler.instance.href == nil && DownloadsScriptMessageHandler.instance.src == nil
    }
    
    @objc private func openLinkAction(_ sender: NSMenuItem) {
        guard let urlString = DownloadsScriptMessageHandler.instance.href else { return }
        if urlString.hasPrefix("file:///") {
            let targetURL = URL(fileURLWithPath: urlString)
            ArticleWebViewModel.shared.processInternalFileLink(targetURL)
        }
        if let url = URL(string: urlString) {
            ArticleWebViewModel.shared.processPossibleInternalLink(url)
            if !ArticleWebViewModel.shared.checkInternalLink(url) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func downloadFileAction(_ sender: NSMenuItem) {
        if let _ = DownloadsScriptMessageHandler.instance.href, let srcString = DownloadsScriptMessageHandler.instance.src {
            self.load(URLRequest(url: URL(string: srcString)!))
        } else if let urlString = DownloadsScriptMessageHandler.instance.href {
            self.load(URLRequest(url: URL(string: urlString)!))
        } else if let srcString = DownloadsScriptMessageHandler.instance.src {
            self.load(URLRequest(url: URL(string: srcString)!))
        }
    }
    
    @objc private func openImageAction(_ sender: NSMenuItem) {
        if let _ = DownloadsScriptMessageHandler.instance.href, let srcString = DownloadsScriptMessageHandler.instance.src {
            NSWorkspace.shared.open(URL(string: srcString)!)
        } else if let urlString = DownloadsScriptMessageHandler.instance.href {
            NSWorkspace.shared.open(URL(string: urlString)!)
        } else if let srcString = DownloadsScriptMessageHandler.instance.src {
            NSWorkspace.shared.open(URL(string: srcString)!)
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
