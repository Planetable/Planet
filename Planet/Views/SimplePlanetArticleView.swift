//
//  SimplePlanetArticleView.swift
//  Planet
//
//  Created by Kai on 2/26/22.
//

import SwiftUI
import WebKit


struct SimplePlanetArticleView: View {
    @Binding var url: URL
    
    var body: some View {
        SimpleWebView(url: url)
    }
}

struct SimpleWebView: NSViewRepresentable {
    
    public typealias NSViewType = WKWebView
    
    let url: URL
    let navigationHelper = WebViewHelper()

    func makeNSView(context: NSViewRepresentableContext<SimpleWebView>) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = navigationHelper

        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webview.load(request)
        return webview
    }

    func updateNSView(_ webview: WKWebView, context: NSViewRepresentableContext<SimpleWebView>) {
        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webview.load(request)
    }
}

class WebViewHelper: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}
