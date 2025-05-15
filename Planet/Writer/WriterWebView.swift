import SwiftUI
import WebKit

struct WriterWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView
    
    @ObservedObject var draft: DraftModel

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WriterWebView
        var draft: DraftModel
        
        init(parent: WriterWebView, draft: DraftModel) {
            self.parent = parent
            self.draft = draft
        }
        
        deinit {
            debugPrint("WriterWebView coordinator deinit: \(parent)")
        }
        
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
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self, draft: draft)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.loadFileURL(draft.previewPath, allowingReadAccessTo: draft.attachmentsPath)
        nsView.evaluateJavaScript("scrollPosition(\(draft.scrollerOffset));")
    }
}
