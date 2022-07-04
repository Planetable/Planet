import SwiftUI
import WebKit

struct WriterWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView

    let draft: DraftModel
    let navigationHelper = WriterWebViewHelper()

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = navigationHelper
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadFileURL(draft.previewPath, allowingReadAccessTo: draft.attachmentsPath)
        NotificationCenter.default.addObserver(
            forName: .writerNotification(.loadPreview, for: draft),
            object: nil,
            queue: .main
        ) { _ in
            webView.evaluateJavaScript("saveScroll();") { _, error in
                if let error = error {
                    debugPrint("failed to evaluate js: \(error)")
                }
                webView.loadFileURL(draft.previewPath, allowingReadAccessTo: draft.attachmentsPath)
            }
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // modify the webview here cannot load/reload the page, i.e. WebKit does not respond to URL change
        // however, execute JavaScript works
    }
}

class WriterWebViewHelper: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(true)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let scheme = components.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
