import SwiftUI
import WebKit

struct WriterWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView

    var url: URL
    let navigationHelper = PlanetWriterWebViewHelper()

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = false
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = navigationHelper
        wv.setValue(false, forKey: "drawsBackground")
        wv.loadFileRequest(URLRequest(url: url), allowingReadAccessTo: url)
        return wv
    }

    func updateNSView(_ webview: WKWebView, context: NSViewRepresentableContext<WriterWebView>) {
        // debugPrint("update web view (\(webview) with url: \(url)")
        // webview.loadFileRequest(URLRequest(url: url), allowingReadAccessTo: url)
    }
}

class PlanetWriterWebViewHelper: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(true)
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
