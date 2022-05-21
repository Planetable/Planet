//
//  PlanetArticleWebView.swift
//  Planet
//
//  Created by Kai on 2/26/22.
//

import SwiftUI
import WebKit


class PlanetWebViewHelper: NSObject {
    static let shared = PlanetWebViewHelper()

    override init() {
        debugPrint("Planet Web View Init.")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        debugPrint("Planet Web View Deinit.")
    }

    func cleanCookies() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            for record in records {
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        }
    }
}


struct PlanetArticleWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView

    let navigationHelper = PlanetArticleWebViewHelper.shared
    let wv = WKWebView()
    
    @Binding var url: URL

    func makeNSView(context: Context) -> WKWebView {
        debugPrint("makeNSView")
        wv.navigationDelegate = navigationHelper
        wv.setValue(false, forKey: "drawsBackground")
        wv.load(URLRequest(url: url))

        NotificationCenter.default.addObserver(forName: .refreshArticle, object: nil, queue: .main) { _ in
            debugPrint("reloading article at: \(url)")
            wv.reload()
        }

        NotificationCenter.default.addObserver(forName: .loadArticle, object: nil, queue: .main) { _ in
            if wv.url != url {
                debugPrint("loading article at: \(url)")
                wv.load(URLRequest(url: url))
            }
        }

        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }
}


class PlanetArticleWebViewHelper: NSObject, WKNavigationDelegate {
    static let shared = PlanetArticleWebViewHelper()

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
