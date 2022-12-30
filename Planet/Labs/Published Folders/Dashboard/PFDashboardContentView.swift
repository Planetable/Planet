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
    
    @Binding var url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> PFDashboardWebView {
        let wv = PFDashboardWebView()
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: url))
        wv.allowsBackForwardNavigationGestures = false
        NotificationCenter.default.addObserver(forName: .dashboardLoadPreviewURL, object: nil, queue: .main) { n in
            let targetURL: URL
            if let previewURL = n.object as? URL {
                targetURL = previewURL
                if wv.canGoBack, let backItem = wv.backForwardList.backList.first {
                    wv.go(to: backItem)
                }
            } else {
                targetURL = self.url
            }
            wv.load(URLRequest(url: targetURL))
        }
        NotificationCenter.default.addObserver(forName: .dashboardProcessDirectoryURL, object: nil, queue: nil) { n in
            Task { @MainActor in
                try? await wv.evaluateJavaScript("document.getElementById('page-header').outerHTML = '';")
            }
        }
        NotificationCenter.default.addObserver(forName: .dashboardWebViewGoForward, object: nil, queue: .main) { _ in
            wv.goForward()
        }
        NotificationCenter.default.addObserver(forName: .dashboardWebViewGoBackward, object: nil, queue: .main) { _ in
            wv.goBack()
        }
        NotificationCenter.default.addObserver(forName: .dashboardReloadWebView, object: nil, queue: .main) { _ in
            wv.reload()
        }
        NotificationCenter.default.addObserver(forName: .dashboardWebViewGoHome, object: nil, queue: .main) { _ in
            resetNavigationHome()
        }
        return wv
    }
    
    func updateNSView(_ nsView: PFDashboardWebView, context: Context) {
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
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
            if await IPFSState.shared.online == false {
                return (.cancel, preferences)
            }
            let noSelectionURL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
            if let url = navigationAction.request.url {
                // handle requests from non-daemon servers with system browsers
                if url.isFileURL {
                } else if url == noSelectionURL {
                } else if (url.host == "127.0.0.1" || url.host == "localhost") && UInt16(url.port ?? 0) == IPFSDaemon.shared.gatewayPort {
                } else {
                    NSWorkspace.shared.open(url)
                    return (.cancel, preferences)
                }
            }
            return (.allow, preferences)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let serviceStore = PlanetPublishedServiceStore.shared
            guard let currentURL = webView.url else { return }
            Task { @MainActor in
                serviceStore.updateSelectedFolderNavigation(withCurrentURL: currentURL, canGoForward: webView.canGoForward, forwardURL: webView.backForwardList.forwardItem?.url, canGoBackward: webView.canGoBack, backwardURL: webView.backForwardList.backItem?.url)
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            let serviceStore = PlanetPublishedServiceStore.shared
            guard let currentURL = webView.url else { return }
            guard let selectedID = serviceStore.selectedFolderID, let currentFolder = serviceStore.publishedFolders.first(where: { $0.id == selectedID }) else { return }
            Task (priority: .userInitiated) {
                guard currentURL.hasDirectoryPath else { return }
                guard let _ = currentURL.scheme, let host = currentURL.host, let port = currentURL.port else { return }
                if (host == "127.0.0.1" || host == "localhost") && UInt16(port) == IPFSDaemon.shared.gatewayPort {
                    let indexPage = currentURL.appendingPathComponent("index.html")
                    do {
                        let request = URLRequest(url: indexPage, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 0.1)
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if let httpResponse = response as? HTTPURLResponse {
                            if httpResponse.statusCode != 200 {
                                let info = ["folder": currentFolder, "url": currentURL]
                                NotificationCenter.default.post(name: .dashboardProcessDirectoryURL, object: info)
                            }
                        }
                    } catch {}
                }
            }
        }
    }
}


extension PFDashboardContentView {
    private func resetNavigationHome() {
        let serviceStore = PlanetPublishedServiceStore.shared
        serviceStore.restoreSelectedFolderNavigation()
        NotificationCenter.default.post(name: .dashboardRefreshToolbar, object: nil)
    }
}
