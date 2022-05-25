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

    private let wv: WKWebView = WKWebView(frame: CGRect.zero, configuration: WKWebViewConfiguration())

    @Binding var url: URL
    let navigationHelper = TemplateBrowserPreviewWebViewHelper.shared

    func makeNSView(context: Context) -> WKWebView {
        wv.navigationDelegate = navigationHelper
        if navigationHelper.waitingForFirstReload {
            wv.isHidden = true
        }
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            debugPrint("nsView.url: \(nsView.url)")
            debugPrint("url: \(url)")
            nsView.load(URLRequest(url: url))
        }
    }
}


class TemplateBrowserPreviewWebViewHelper: NSObject, WKNavigationDelegate {
    static let shared = TemplateBrowserPreviewWebViewHelper()

    var waitingForFirstReload: Bool = true

    func webView(_ webView: WKWebView, shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge) async -> Bool {
        return true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if waitingForFirstReload {
            assert(webView.isHidden)
            waitingForFirstReload = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                webView.isHidden = false
            }
        } else {

        }
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
