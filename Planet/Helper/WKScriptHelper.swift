//
//  WKScriptHelper.swift
//  Planet
//
//  Created by Kai on 12/13/22.
//

import Cocoa
import WebKit


/*
 https://stackoverflow.com/questions/28801032/how-can-the-context-menu-in-wkwebview-on-the-mac-be-modified-or-overridden
 */
class DownloadsScriptMessageHandler: NSObject, WKScriptMessageHandler {

    public private(set) static var instance = DownloadsScriptMessageHandler()

    public private(set) var nodeName: String?
    public private(set) var nodeId: String?
    public private(set) var hrefNodeName: String?
    public private(set) var hrefNodeId: String?
    public private(set) var href: String?
    public private(set) var src: String?

    static private var contextMenuScript = """
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

    static private var internalLinkScript = """
        window.onclick = (e) => {
          const target = e.target;
          console.log(target);
          const href = target.href;
          if (href) {
            window.webkit.messageHandlers.buttonclicked.postMessage({
              linkClicked: href
            });
          }
          const itemID = target.id;
          // if itemID has prefix "todo-item-", then it's a todo item
          if (itemID && itemID.startsWith("todo-item-")) {
            const selector = itemID;
            const checkbox = document.querySelector(`#${selector}>input[type="checkbox"]`);
            // toggle checkbox
            checkbox.checked = !checkbox.checked;
            window.webkit.messageHandlers.todoitems.postMessage({
              todoItem: itemID
            });
          }
        }
        """

    private override init() {
        super.init()
    }

    public func ensureHandles(configuration: WKWebViewConfiguration) {
        var alreadyHandling = false
        for userScript in configuration.userContentController.userScripts {
            if userScript.source == DownloadsScriptMessageHandler.contextMenuScript {
                alreadyHandling = true
            }
        }

        if !alreadyHandling {
            let userContentController = configuration.userContentController

            userContentController.add(self, name: "oncontextmenu")
            userContentController.add(self, name: "buttonclicked")
            userContentController.add(self, name: "todoitems")

            let contextMenuScript = WKUserScript(source: DownloadsScriptMessageHandler.contextMenuScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userContentController.addUserScript(contextMenuScript)

            let internalLinkScript = WKUserScript(source: DownloadsScriptMessageHandler.internalLinkScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userContentController.addUserScript(internalLinkScript)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? NSDictionary {
            debugPrint("WKWebView message: \(body)");

            nodeName = body["nodeName"] as? String
            nodeId = body["id"] as? String
            hrefNodeName = body["hrefNodeName"] as? String
            hrefNodeId = body["hrefId"] as? String
            href = body["href"] as? String
            src = body["src"] as? String

            // handle internal link from single click
            if let linkClicked = body["linkClicked"] as? String {
                // relative link with file:/// scheme
                if linkClicked.hasPrefix("file:///") {
                    let targetURL = URL(fileURLWithPath: linkClicked)
                    ArticleWebViewModel.shared.processInternalFileLink(targetURL)
                }
                // process possible internal link
                if let targetURL = URL(string: linkClicked) {
                    ArticleWebViewModel.shared.processPossibleInternalLink(targetURL)
                }
            }

            // handle todo item toggle from single click
            if let todoItem = body["todoItem"] as? String {
                Task { @MainActor in
                    if let article = PlanetStore.shared.selectedArticle, let myArticle = article as? MyArticleModel {
                        debugPrint("Toggling todo item: \(todoItem) in \(myArticle.title)")
                        myArticle.toggleToDoItem(item: todoItem)
                    }
                }
            }
        }
    }
}
