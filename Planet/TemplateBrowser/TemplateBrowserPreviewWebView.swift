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

    static var wv: WKWebView!

    @Binding var url: URL
    let navigationHelper = TemplateBrowserPreviewWebViewHelper()

    func makeNSView(context: Context) -> WKWebView {
        if Self.wv == nil || Self.wv.url != url {
            let config = WKWebViewConfiguration()
            Self.wv = WKWebView(frame: .zero, configuration: config)
            Self.wv.navigationDelegate = navigationHelper
            Self.wv.load(URLRequest(url: url))
        }
        return Self.wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if Self.wv.url != url {
            nsView.load(URLRequest(url: url))
        }
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

//    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
//        preferences.preferredContentMode = .desktop
//        preferences.allowsContentJavaScript = true
//        return (.allow, preferences)
//    }
}

extension Notification.Name {
    static let refreshTemplatePreview = Notification.Name("TemplateBrowserRefreshPreviewNotification")
}
