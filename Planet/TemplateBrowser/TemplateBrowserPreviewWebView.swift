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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let wv = TemplateWebView()

        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")

        wv.customUserAgent = "Planet/" + PlanetUpdater.shared.appVersion()

        if url.isFileURL {
            wv.loadFileURL(
                url,
                allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent()
            )
        }
        else {
            wv.load(URLRequest(url: url))
        }

        NotificationCenter.default.addObserver(
            forName: .loadTemplatePreview,
            object: nil,
            queue: .main
        ) { _ in
            debugPrint(
                "Loading template preview from: \(url), user agent: \(wv.customUserAgent ?? "")"
            )
            if url.isFileURL {
                wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent())
            }
            else {
                wv.load(URLRequest(url: url))
            }
        }
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: TemplateBrowserPreviewWebView

        init(_ parent: TemplateBrowserPreviewWebView) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView,
            shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge
        ) async -> Bool {
            return true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
        {
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
        }

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) ->
                Void
        ) {
            completionHandler(.performDefaultHandling, nil)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    if components?.scheme == "http" || components?.scheme == "https" {
                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
            decisionHandler(.allow)
        }
    }
}

extension Notification.Name {
    static let refreshTemplatePreview = Notification.Name(
        "TemplateBrowserRefreshPreviewNotification"
    )

    static let loadTemplatePreview = Notification.Name("TemplateBrowserLoadPreviewNotification")
}
