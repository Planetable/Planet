//
//  PFDashboardContentView.swift
//  Planet
//
//  Created by Kai on 12/18/22.
//

import Foundation
import SwiftUI
import WebKit


struct PFDashboardContentView: NSViewRepresentable {
    
    var url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> PFDashboardWebView {
        let wv = PFDashboardWebView()
        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        wv.load(URLRequest(url: url))
        NotificationCenter.default.addObserver(forName: .dashboardReloadCurrentURL, object: nil, queue: .main) { _ in
            wv.load(URLRequest(url: self.url))
        }
        return wv
    }
    
    func updateNSView(_ nsView: PFDashboardWebView, context: Context) {
        nsView.load(URLRequest(url: url))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: PFDashboardContentView
        
        init(_ parent: PFDashboardContentView) {
            self.parent = parent
        }
        
        // MARK: - NavigationDelegate
        
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}