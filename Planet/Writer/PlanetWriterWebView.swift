//
//  PlanetWriterWebView.swift
//  Planet
//
//  Created by Kai on 3/30/22.
//

import SwiftUI
import WebKit


struct PlanetWriterWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView

    @State private var previousState: Any!
    var url: URL
    var targetID: UUID
    @State var offset: CGFloat = 0

    let navigationHelper = PlanetWriterWebViewHelper()

    func makeNSView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = navigationHelper
        webview.loadFileRequest(URLRequest(url: url), allowingReadAccessTo: url)
        let reloadNotification = Notification.Name.notification(notification: .reloadPage, forID: targetID)
        NotificationCenter.default.addObserver(forName: reloadNotification, object: nil, queue: .main) { n in
            guard let targetPath = n.object as? URL else { return }
            debugPrint("reloading url: \(targetPath)")
            webview.loadFileRequest(URLRequest(url: targetPath), allowingReadAccessTo: targetPath)
            self.executeJSActions(withWebView: webview, js: "refreshPreview();")
        }
        let scrollNotification = Notification.Name.notification(notification: .scrollPage, forID: targetID)
        NotificationCenter.default.addObserver(forName: scrollNotification, object: nil, queue: .main) { n in
            guard let offset = n.object as? NSNumber else { return }
            debugPrint("scrolling to offset: \(offset.floatValue)")
            self.executeJSActions(withWebView: webview, js: "scrollPosition(\(offset.floatValue));")
        }
        return webview
    }

    func updateNSView(_ webview: WKWebView, context: NSViewRepresentableContext<PlanetWriterWebView>) {
        debugPrint("update web view (\(webview) with url: \(url)")
        webview.loadFileRequest(URLRequest(url: url), allowingReadAccessTo: url)
    }

    private func executeJSActions(withWebView webview: WKWebView, js: String) {
        webview.evaluateJavaScript(js) { _, error in
            if let error = error {
                debugPrint("failed to evaluate js: \(error)")
            } else {
                debugPrint("js evaluated: \(js)")
            }
        }
    }
}


class PlanetWriterWebViewHelper: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge) async -> Bool {
        return true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        debugPrint("webView did loaded!")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
//        debugPrint("webView did start provisional navigation.")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//        debugPrint("webView did commit.")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
//        debugPrint("webView did failed provisional navigation.")
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        preferences.preferredContentMode = .desktop
        preferences.allowsContentJavaScript = true
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if components?.scheme == "http" || components?.scheme == "https" {
                    NSWorkspace.shared.open(url)
                    return (.cancel, preferences)
                }
            }
        }
        return (.allow, preferences)
    }
}
