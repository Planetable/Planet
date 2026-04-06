import SwiftUI
import WebKit
import os

struct ArticleWebView: NSViewRepresentable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArticleWebView")

    @Binding var url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> PlanetDownloadsWebView {
        let wv = PlanetDownloadsWebView()

        wv.customUserAgent = "Planet/" + PlanetUpdater.shared.appVersion()

        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        context.coordinator.attach(to: wv)
        context.coordinator.loadCurrentURL(forceReload: true)

        return wv
    }

    func updateNSView(_ nsView: PlanetDownloadsWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attach(to: nsView)
        context.coordinator.loadCurrentURL(forceReload: false)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        var parent: ArticleWebView
        weak var webView: PlanetDownloadsWebView?
        private var observerTokens: [NSObjectProtocol] = []
        private var lastLoadedURL: URL?

        private var navigationType: WKNavigationType = .other

        init(_ parent: ArticleWebView) {
            self.parent = parent
        }

        deinit {
            observerTokens.forEach(NotificationCenter.default.removeObserver)
        }

        func attach(to webView: PlanetDownloadsWebView) {
            self.webView = webView
            guard observerTokens.isEmpty else {
                return
            }

            observerTokens.append(
                NotificationCenter.default.addObserver(
                    forName: .loadArticle,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.loadCurrentURL(forceReload: true)
                }
            )

            observerTokens.append(
                NotificationCenter.default.addObserver(
                    forName: .readerFontSizeChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let webView = self?.webView,
                        let fontSize = notification.object as? NSNumber
                    else {
                        return
                    }
                    webView.evaluateJavaScript(
                        "document.body.style.fontSize = '\(fontSize.intValue)px';"
                    )
                }
            )

            observerTokens.append(
                NotificationCenter.default.addObserver(
                    forName: .downloadArticleAttachment,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let webView = self?.webView,
                        let url = notification.object as? URL
                    else {
                        return
                    }
                    ArticleWebView.logger.log(
                        "Downloading attachment \(url.absoluteString, privacy: .public)"
                    )
                    webView.load(URLRequest(url: url))
                }
            )

            observerTokens.append(
                NotificationCenter.default.addObserver(
                    forName: .updateRuleList,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let webView = self?.webView,
                        let port = notification.object as? NSNumber
                    else {
                        return
                    }
                    ArticleWebView.logger.log("Updating rule list for api port \(port.intValue)")
                    let ruleListString = """
                        [
                            {
                                "trigger": {
                                    "url-filter": "://127.0.0.1:\(port.intValue)/*"
                                },
                                "action": {
                                    "type": "block"
                                }
                            },
                            {
                                "trigger": {
                                    "url-filter": "://localhost:\(port.intValue)/*"
                                },
                                "action": {
                                    "type": "block"
                                }
                            }
                        ]
                    """
                    Task {
                        do {
                            if let contentList = try await WKContentRuleListStore.default()
                                .compileContentRuleList(
                                    forIdentifier: "IPFSAPIPortList",
                                    encodedContentRuleList: ruleListString
                                )
                            {
                                await webView.configuration.userContentController.add(contentList)
                            }
                        } catch {
                            debugPrint("failed to update rule list for article view: \(error)")
                        }
                    }
                }
            )
        }

        func loadCurrentURL(forceReload: Bool) {
            load(parent.url, forceReload: forceReload)
        }

        private func load(_ url: URL, forceReload: Bool) {
            guard let webView else {
                return
            }
            guard forceReload || lastLoadedURL != url else {
                return
            }

            ArticleWebView.logger.log("Loading article url \(url.absoluteString, privacy: .public)")
            if url.isFileURL {
                webView.loadFileURL(url, allowingReadAccessTo: readAccessURL(for: url))
            } else {
                webView.load(URLRequest(url: url))
            }
            lastLoadedURL = url
        }

        private func readAccessURL(for url: URL) -> URL {
            url.deletingLastPathComponent().deletingLastPathComponent()
        }

        private func shouldHandleDownloadForMIMEType(_ mimeType: String) -> Bool {
            return PlanetDownloadItem.downloadableMIMETypes().contains(mimeType)
        }

        private func isValidatedLink(_ url: URL) -> Bool {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if components?.scheme == "http" || components?.scheme == "https" {
                return true
            }
            return false
        }

        // MARK: - NavigationDelegate

        func webView(
            _ webView: WKWebView,
            shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge
        ) async -> Bool {
            true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            debugPrint("ArticleWebView: didFinish \(String(describing: navigation))")
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
        {
            debugPrint(
                "ArticleWebView: didStartProvisionalNavigation \(String(describing: navigation)) \(navigationType)"
            )
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            debugPrint("ArticleWebView: didCommit \(String(describing: navigation))")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            debugPrint("ArticleWebView: didFailProvisionalNavigation \(String(describing: navigation))")
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
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            debugPrint("WKWebView decidePolicyFor: action: \(navigationAction) / url: \(String(describing: navigationAction.request.url))")
            // handle (ignore) target="_blank" (open in new window) link as external
            if navigationAction.targetFrame == nil, let externalURL = navigationAction.request.url,
               isValidatedLink(externalURL) {
                if !externalURL.isPlanetWindowGroupLink {
                    NSWorkspace.shared.open(externalURL)
                }
                decisionHandler(.cancel, preferences)
            } else if let targetLink = navigationAction.request.url {
                if targetLink.isPlanetWindowGroupLink {
                    decisionHandler(.cancel, preferences)
                } else if ArticleWebViewModel.shared.checkInternalLink(targetLink) {
                    decisionHandler(.cancel, preferences)
                } else if isValidatedLink(targetLink) {
                    if PlanetDownloadItem.downloadableFileExtensions().contains(targetLink.pathExtension) {
                        decisionHandler(.allow, preferences)
                    } else if navigationAction.navigationType == .linkActivated {
                        NSWorkspace.shared.open(targetLink)
                        decisionHandler(.cancel, preferences)
                    } else {
                        decisionHandler(.allow, preferences)
                    }
                } else {
                    decisionHandler(.allow, preferences)
                }
            } else {
                if navigationAction.shouldPerformDownload {
                    decisionHandler(.download, preferences)
                } else {
                    decisionHandler(.allow, preferences)
                }
            }
            navigationType = navigationAction.navigationType
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.canShowMIMEType, let url = navigationResponse.response.url,
               let mimeType = navigationResponse.response.mimeType
            {
                if shouldHandleDownloadForMIMEType(mimeType) || PlanetDownloadItem.downloadableFileExtensions().contains(url.pathExtension) {
                    debugPrint("branch 1 condition 1: shouldHandleDownloadForMIMEType: \(shouldHandleDownloadForMIMEType(mimeType))")
                    debugPrint("branch 1 condition 2: downloadableFileExtensions: \(PlanetDownloadItem.downloadableFileExtensions().contains(url.pathExtension))")
                    debugPrint(
                        "WKNavigationResponse: .download branch 1 -> canShowMIMEType: \(navigationResponse.canShowMIMEType), url: \(String(describing: navigationResponse.response.url)), mimeType: \(String(describing: navigationResponse.response.mimeType))"
                    )
                    decisionHandler(.download)
                }
                else {
                    debugPrint(
                        "WKNavigationResponse: .allow -> canShowMIMEType: \(navigationResponse.canShowMIMEType), url: \(String(describing: navigationResponse.response.url)), mimeType: \(String(describing: navigationResponse.response.mimeType))"
                    )
                    decisionHandler(.allow)
                }
            }
            else {
                debugPrint(
                    "WKNavigationResponse: .download branch 2 -> canShowMIMEType: \(navigationResponse.canShowMIMEType), url: \(String(describing: navigationResponse.response.url)), mimeType: \(String(describing: navigationResponse.response.mimeType))"
                )
                decisionHandler(.download)
            }
            ArticleWebViewModel.shared.removeInternalLinks()
        }

        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            // MARK: TODO: detect running downloads before start new one.
            download.delegate = self
        }

        // MARK: - DownloadDelegate

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let downloadsDir = tempDir.appendingPathComponent("Downloads")
            if !FileManager.default.fileExists(atPath: downloadsDir.path) {
                try? FileManager.default.createDirectory(
                    at: downloadsDir,
                    withIntermediateDirectories: true
                )
            }
            let downloadURL = downloadsDir.appendingPathComponent(suggestedFilename)
            if FileManager.default.fileExists(atPath: downloadURL.path) {
                if let userDownloadsDir = FileManager.default.urls(
                    for: .downloadsDirectory,
                    in: .userDomainMask
                ).first {
                    let downloadedURL = userDownloadsDir.appendingPathComponent(suggestedFilename)
                    try? FileManager.default.moveItem(at: downloadURL, to: downloadedURL)
                    NSWorkspace.shared.activateFileViewerSelecting([downloadedURL])
                }
                completionHandler(nil)
            }
            else {
                let downloadItem = PlanetDownloadItem(
                    id: UUID(),
                    created: Date(),
                    download: download
                )
                Task { @MainActor in
                    PlanetDownloadsViewModel.shared.addDownload(downloadItem)
                }
                completionHandler(downloadURL)
                PlanetAppDelegate.shared.openDownloadsWindow()
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            // MARK: TODO: handle failed download task.
        }

        func downloadDidFinish(_ download: WKDownload) {
            if let url = download.progress.fileURL,
               let userDownloadsDir = FileManager.default.urls(
                for: .downloadsDirectory,
                in: .userDomainMask
               ).first
            {
                let downloadedURL = userDownloadsDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.moveItem(at: url, to: downloadedURL)
                NSWorkspace.shared.activateFileViewerSelecting([downloadedURL])
            }
        }

        func download(
            _ download: WKDownload,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) ->
            Void
        ) {
            completionHandler(.performDefaultHandling, nil)
        }

        func download(
            _ download: WKDownload,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }
    }
}
