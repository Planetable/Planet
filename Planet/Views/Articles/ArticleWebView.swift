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
            debugPrint("WKWebView decidePolicyFor: action: \(navigationAction) / url: \(navigationAction.request.url)")
            // handle (ignore) target="_blank" (open in new window) link as external
            if navigationAction.targetFrame == nil, let externalURL = navigationAction.request.url,
               isValidatedLink(externalURL)
            {
                NSWorkspace.shared.open(externalURL)
                decisionHandler(.cancel, preferences)
            }
            else if let targetLink = navigationAction.request.url {
                var existings = ArticleWebViewModel.shared.checkPlanetLink(targetLink)
                defer {
                    existings.mine = nil
                    existings.following = nil
                }
                if targetLink.isPlanetLink {
//                    if !ArticleWebViewModel.shared.checkActivePlanet(myPlanet: existings.mine, followingPlanet: existings.following) {
//                    }
                    if let myPlanet: MyPlanetModel = existings.mine {
                        Task.detached { @MainActor in
                            PlanetStore.shared.selectedView = .myPlanet(myPlanet)
                        }
                    }
                    else if let followingPlanet: FollowingPlanetModel = existings.following {
                        Task.detached { @MainActor in
                            PlanetStore.shared.selectedView = .followingPlanet(followingPlanet)
                        }
                    }
                    else {
                        var existings = ArticleWebViewModel.shared.checkArticleLink(targetLink)
                        defer {
                            existings.mine = nil
                            existings.following = nil
                            existings.myArticle = nil
                            existings.followingArticle = nil
                        }
                        if let mine = existings.mine, let myArticle = existings.myArticle {
                            Task.detached { @MainActor in
                                if let aList = PlanetStore.shared.selectedArticleList, aList.contains(myArticle) {

                                } else {
                                    PlanetStore.shared.selectedView = .myPlanet(mine)
                                    Task { @MainActor in
                                        PlanetStore.shared.selectedArticle = myArticle
                                        PlanetStore.shared.refreshSelectedArticles()
                                    }
                                }
//                                PlanetStore.shared.selectedView = .myPlanet(mine)
//                                Task { @MainActor in
//                                    PlanetStore.shared.selectedArticle = myArticle
//                                    PlanetStore.shared.refreshSelectedArticles()
//                                }
                            }
                        }
                        else if let following = existings.following, let followingArticle = existings.followingArticle {
                            Task.detached { @MainActor in
                                if let aList = PlanetStore.shared.selectedArticleList, aList.contains(followingArticle) {

                                } else {
                                    PlanetStore.shared.selectedView = .followingPlanet(following)
                                    Task { @MainActor in
                                        PlanetStore.shared.selectedArticle = followingArticle
                                        PlanetStore.shared.refreshSelectedArticles()
                                    }
                                }
//                                PlanetStore.shared.selectedView = .followingPlanet(following)
//                                Task { @MainActor in
//                                    PlanetStore.shared.selectedArticle = followingArticle
//                                    PlanetStore.shared.refreshSelectedArticles()
//                                }
                            }
                        }
                        else {
                            Task.detached { @MainActor in
                                PlanetStore.shared.followingPlanetLink = targetLink.absoluteString
                                PlanetStore.shared.isFollowingPlanet = true
                            }
                        }
                    }
                    decisionHandler(.cancel, preferences)
                }
                else {
                    var existings = ArticleWebViewModel.shared.checkArticleLink(targetLink)
                    defer {
                        existings.mine = nil
                        existings.following = nil
                        existings.myArticle = nil
                        existings.followingArticle = nil
                    }

//                    if ArticleWebViewModel.shared.checkActiveArticle(myArticle: existings.myArticle, followingArticle: existings.followingArticle) {
//                        decisionHandler(.cancel, preferences)
//                        return
//                    }

                    if let mine = existings.mine, let myArticle = existings.myArticle {
                        Task.detached { @MainActor in
                            if let aList = PlanetStore.shared.selectedArticleList, let article = aList.first(where: { item in
                                if let my = item as? MyArticleModel  {
                                    return aList.contains(my)
                                }
                                if let following = item as? FollowingArticleModel {
                                    return aList.contains(following)
                                }
                                return false
                            }) {

                            } else {
                                PlanetStore.shared.selectedView = .myPlanet(mine)
                                Task { @MainActor in
                                    PlanetStore.shared.selectedArticle = myArticle
                                    PlanetStore.shared.refreshSelectedArticles()
                                }
                            }
                        }
                        decisionHandler(.allow, preferences)
                    }
                    else if let following = existings.following, let followingArticle = existings.followingArticle {
                        Task.detached { @MainActor in
                            if let aList = PlanetStore.shared.selectedArticleList, let article = aList.first(where: { item in
                                if let my = item as? MyArticleModel  {
                                    return aList.contains(my)
                                }
                                if let following = item as? FollowingArticleModel {
                                    return aList.contains(following)
                                }
                                return false
                            }) {
                            } else {
                                PlanetStore.shared.selectedView = .followingPlanet(following)
                                Task { @MainActor in
                                    PlanetStore.shared.selectedArticle = followingArticle
                                    PlanetStore.shared.refreshSelectedArticles()
                                }
                            }
                        }
                        decisionHandler(.allow, preferences)
                    }
                    else {
                        if isValidatedLink(targetLink), PlanetDownloadItem.downloadableFileExtensions().contains(targetLink.pathExtension) {
                            decisionHandler(.allow, preferences)
                        }
                        else if navigationAction.navigationType == .linkActivated, isValidatedLink(targetLink) {
                            NSWorkspace.shared.open(targetLink)
                            decisionHandler(.cancel, preferences)
                        }
                        else {
                            decisionHandler(.allow, preferences)
                        }
                    }
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
                if shouldHandleDownloadForMIMEType(mimeType) || PlanetDownloadItem.downloadableFileExtensions().contains(url.pathExtension) {
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
