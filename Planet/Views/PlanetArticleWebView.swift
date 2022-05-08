//
//  PlanetArticleWebView.swift
//  Planet
//
//  Created by Kai on 2/26/22.
//

import SwiftUI
import WebKit


struct PlanetArticleWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView
    @Binding var url: URL
    let navigationHelper = PlanetWriterWebViewHelper()

    func makeNSView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = navigationHelper
        webview.load(URLRequest(url: url))
        return webview
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.load(URLRequest(url: url))
    }
}


class PlanetArticleWebViewHelper: NSObject, WKNavigationDelegate {
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
        // MARK: TODO: Add more navigation link process logic.
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
