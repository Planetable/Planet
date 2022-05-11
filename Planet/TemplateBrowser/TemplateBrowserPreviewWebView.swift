//
//  TemplateBrowserPreviewWebView.swift
//  Planet
//
//  Created by Xin Liu on 5/11/22.
//

import SwiftUI
import WebKit


struct TemplateBrowserPreviewWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView
    @Binding var url: URL
    let navigationHelper = TemplateBrowserPreviewWebViewHelper()

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


class TemplateBrowserPreviewWebViewHelper: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge) async -> Bool {
        return true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        preferences.preferredContentMode = .desktop
        preferences.allowsContentJavaScript = true
        return (.allow, preferences)
    }
}

