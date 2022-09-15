//
//  PlanetDownloadsWebView.swift
//  Planet
//
//  Created by Kai on 8/3/22.
//

import Cocoa
import WebKit


/*
 https://stackoverflow.com/questions/28801032/how-can-the-context-menu-in-wkwebview-on-the-mac-be-modified-or-overridden
 */
private class GlobalScriptMessageHandler: NSObject, WKScriptMessageHandler {
    
    public private(set) static var instance = GlobalScriptMessageHandler()
    
    public private(set) var nodeName: String?
    public private(set) var nodeId: String?
    public private(set) var hrefNodeName: String?
    public private(set) var hrefNodeId: String?
    public private(set) var href: String?
    public private(set) var src: String?
    
    static private var WHOLE_PAGE_SCRIPT = """
        window.oncontextmenu = (event) => {
            var target = event.target
            var src = target.src
            var href = target.href
            var parentElement = target
            while (href == null && parentElement.parentElement != null) {
                parentElement = parentElement.parentElement
                href = parentElement.href
            }

            if (href == null) {
                parentElement = null;
            }

            window.webkit.messageHandlers.oncontextmenu.postMessage({
                nodeName: target.nodeName,
                id: target.id,
                hrefNodeName: parentElement?.nodeName,
                hrefId: parentElement?.id,
                href,
                src
            });
        }
        """
    
    private override init() {
        super.init()
    }
    
    public func ensureHandles(configuration: WKWebViewConfiguration) {
        var alreadyHandling = false
        for userScript in configuration.userContentController.userScripts {
            if userScript.source == GlobalScriptMessageHandler.WHOLE_PAGE_SCRIPT {
                alreadyHandling = true
            }
        }
        
        if !alreadyHandling {
            let userContentController = configuration.userContentController
            userContentController.add(self, name: "oncontextmenu")
            let userScript = WKUserScript(source: GlobalScriptMessageHandler.WHOLE_PAGE_SCRIPT, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userContentController.addUserScript(userScript)
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? NSDictionary {
            nodeName = body["nodeName"] as? String
            nodeId = body["id"] as? String
            hrefNodeName = body["hrefNodeName"] as? String
            hrefNodeId = body["hrefId"] as? String
            href = body["href"] as? String
            src = body["src"] as? String
        }
    }
}

class PlanetDownloadsWebView: WKWebView {
    
    init() {
        super.init(frame: CGRect(), configuration: WKWebViewConfiguration())
        GlobalScriptMessageHandler.instance.ensureHandles(configuration: self.configuration)
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
            if let _ = GlobalScriptMessageHandler.instance.src, let href = GlobalScriptMessageHandler.instance.href {
                url = URL(string: href)
            } else if let src = GlobalScriptMessageHandler.instance.src {
                url = URL(string: src)
            } else if let href = GlobalScriptMessageHandler.instance.href {
                url = URL(string: href)
            }
            if let url = url {
                return !PlanetDownloadItem.downloadableFileExtensions().contains(url.pathExtension)
            } else {
                return true
            }
        }
        return GlobalScriptMessageHandler.instance.href == nil && GlobalScriptMessageHandler.instance.src == nil
    }
    
    @objc private func openLinkAction(_ sender: NSMenuItem) {
        if let urlString = GlobalScriptMessageHandler.instance.href {
            let url = URL(string: urlString)!
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func downloadFileAction(_ sender: NSMenuItem) {
        if let _ = GlobalScriptMessageHandler.instance.href, let srcString = GlobalScriptMessageHandler.instance.src {
            self.load(URLRequest(url: URL(string: srcString)!))
        } else if let urlString = GlobalScriptMessageHandler.instance.href {
            self.load(URLRequest(url: URL(string: urlString)!))
        } else if let srcString = GlobalScriptMessageHandler.instance.src {
            self.load(URLRequest(url: URL(string: srcString)!))
        }
    }
    
    @objc private func openImageAction(_ sender: NSMenuItem) {
        if let _ = GlobalScriptMessageHandler.instance.href, let srcString = GlobalScriptMessageHandler.instance.src {
            NSWorkspace.shared.open(URL(string: srcString)!)
        } else if let urlString = GlobalScriptMessageHandler.instance.href {
            NSWorkspace.shared.open(URL(string: urlString)!)
        } else if let srcString = GlobalScriptMessageHandler.instance.src {
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
