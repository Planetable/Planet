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
        if url.isFileURL {
            wv.loadFileURL(
                url,
                allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent()
            )
        }
        else {
            wv.load(URLRequest(url: url))
        }

        NotificationCenter.default.addObserver(forName: .loadArticle, object: nil, queue: .main) {
            _ in
            Self.logger.log("Loading \(url), user agent: \(wv.customUserAgent ?? "")")
            if url.isFileURL {
                wv.loadFileURL(
                    url,
                    allowingReadAccessTo: url.deletingLastPathComponent()
                        .deletingLastPathComponent()
                )
            }
            else {
                wv.load(URLRequest(url: url))
            }
        }

        NotificationCenter.default.addObserver(
            forName: .downloadArticleAttachment,
            object: nil,
            queue: nil
        ) { n in
            Self.logger.log("Downloading \(url)")
            guard let url = n.object as? URL else { return }
            wv.load(URLRequest(url: url))
        }

        return wv
    }

    func updateNSView(_ nsView: PlanetDownloadsWebView, context: Context) {
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        let parent: ArticleWebView

        private var navigationType: WKNavigationType = .other

        init(_ parent: ArticleWebView) {
            self.parent = parent
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

        private func isPlanetLink(_ url: URL) -> Bool {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if components?.scheme == "planet" {
                return true
            }
            return false
        }

        private func isInternalArticleLink(_ url: URL) -> Bool {
            // file link is not an internal link, check for local and public gateway article links:
            /*
             // public
             https://www.cloudflare-ipfs.com/ipns/k51qzi5uqu5dgt38bap3uz6k0sizcscrl2khow28r2148yietg6qkok20ncsu3/57A5E55F-1162-4C05-948C-768FDEEF2C31/

             // local
             http://127.0.0.1:18181/ipfs/bafybeidu5amq53cmc6mn6timcopof63dk5674gjhaguyogjuunkcykxd7e/3C473A64-4309-4CFC-BD7C-80E23C3C391D/
             */
            debugPrint("checking if it is internal url: \(url)")
            if let scheme = url.scheme, let host = url.host, let port = url.port {
                let uuidString = url.lastPathComponent
                let cidString = url.deletingLastPathComponent().lastPathComponent
                let ipfsTag = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
                debugPrint("scheme: \(scheme), host: \(host), port: \(port), uuid: \(uuidString), cid: \(cidString), ipfs tag: \(ipfsTag)")
                if let _ = UUID(uuidString: uuidString), cidString.count == "bafybeigbofhj4t4uxqwd7u6lxdqve3xazrjchagwsoqtcxilpge6sexnuq".count, ipfsTag == "ipfs", port == IPFSDaemon.shared.gatewayPort {
                    debugPrint("is internal link")
                    return true
                }
            } else {
                debugPrint("not internal link.")
            }
            return false
        }

        @MainActor private func findInternalArticleLink(url: URL) -> ArticleModel? {
            let urlString = url.lastPathComponent
            if let range = urlString.range(
                of:
                    #"[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}"#,
                options: .regularExpression
            ) {
                let uuidString = urlString[range]
                debugPrint("WKNavigationResponse: Found UUID: \(uuidString)")
                if let article = PlanetStore.shared.selectedArticleList?.first(where: { item in
                    if let followingArticle = item as? FollowingArticleModel {
                        return followingArticle.link.contains(uuidString)
                    }
                    if let myArticle = item as? MyArticleModel {
                        return myArticle.link.contains(uuidString)
                    }
                    debugPrint("WKNavigationResponse: Found UUID but not matching article: \(uuidString)")
                    return false
                }) {
                    if article.id.uuidString != PlanetStore.shared.selectedArticle?.id.uuidString {
                        debugPrint("WKNavigationResponse: Found matching article: \(article.title)")
                        return article
                    }
                }
            }
            return nil
        }

        // MARK: - NavigationDelegate

        func webView(
            _ webView: WKWebView,
            shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge
        ) async -> Bool {
            true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            debugPrint("ArticleWebView: didFinish \(navigation)")
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
        {
            debugPrint(
                "ArticleWebView: didStartProvisionalNavigation \(navigation) \(navigationType)"
            )
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            debugPrint("ArticleWebView: didCommit \(navigation)")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            debugPrint("ArticleWebView: didFailProvisionalNavigation \(navigation)")
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
            // handle (ignore) target="_blank" (open in new window) link as external
            if navigationAction.targetFrame == nil, let externalURL = navigationAction.request.url,
               isValidatedLink(externalURL)
            {
                NSWorkspace.shared.open(externalURL)
                decisionHandler(.cancel, preferences)
                return
            }
            else if let targetLink = navigationAction.request.url, isPlanetLink(targetLink) {
                debugPrint("processing planet link: \(targetLink)")
                var existings = ArticleWebViewModel.shared.checkPlanetLink(targetLink)
                if let mime: MyPlanetModel = existings.mime {

                    decisionHandler(.cancel, preferences)
                    return
                }
                else if let following: FollowingPlanetModel = existings.following {

                    decisionHandler(.cancel, preferences)
                    return
                }
                else {

                    // Ask to follow or view directly with .limo link.

                    decisionHandler(.allow, preferences)
                    return
                }
                existings.mime = nil
                existings.following = nil
            }
            else if let targetLink = navigationAction.request.url, isInternalArticleLink(targetLink) {
                debugPrint("processing article link: \(targetLink)")
                var existings = ArticleWebViewModel.shared.checkArticleLink(targetLink)
                if let mime = existings.mime, let myArticle = existings.myArticle {

                    decisionHandler(.cancel, preferences)
                    return
                }
                else if let following = existings.following, let publicArticle = existings.publicArticle {

                    decisionHandler(.cancel, preferences)
                    return
                }
                else {
                    // continue with internal link.
                    decisionHandler(.allow, preferences)
                    return
                }
            }
            else {
                if navigationAction.shouldPerformDownload {
                    decisionHandler(.download, preferences)
                }
                else {
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
                if shouldHandleDownloadForMIMEType(mimeType) {
                    debugPrint(
                        "WKNavigationResponse: .download branch 1 -> canShowMIMEType: \(navigationResponse.canShowMIMEType), url: \(String(describing: navigationResponse.response.url)), mimeType: \(String(describing: navigationResponse.response.mimeType))"
                    )
                    decisionHandler(.download)
                }
                else {
                    if navigationType == .linkActivated, isValidatedLink(url) {
                        debugPrint(
                            "WKNavigationResponse: open in external browser -> canShowMIMEType: \(navigationResponse.canShowMIMEType), url: \(String(describing: navigationResponse.response.url)), mimeType: \(String(describing: navigationResponse.response.mimeType))"
                        )
                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
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
