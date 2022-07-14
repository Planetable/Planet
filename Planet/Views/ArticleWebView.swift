import SwiftUI
import WebKit
import os

struct ArticleWebView: NSViewRepresentable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArticleWebView")

    public typealias NSViewType = WKWebView

    @Binding var url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()

        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        if url.isFileURL {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent())
        } else {
            wv.load(URLRequest(url: url))
        }

        NotificationCenter.default.addObserver(forName: .loadArticle, object: nil, queue: .main) { _ in
            Self.logger.log("Loading \(url)")
            if url.isFileURL {
                wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent())
            } else {
                wv.load(URLRequest(url: url))
            }
        }

        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ArticleWebView

        init(_ parent: ArticleWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge) async -> Bool {
            true
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

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
