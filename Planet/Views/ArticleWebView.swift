import SwiftUI
import WebKit
import os

struct ArticleWebView: NSViewRepresentable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArticleWebView")

    @Binding var url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()

        // TODO: probably need a way to inject marketing version here
        wv.customUserAgent = "Planet/0.8.0"

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

    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        let parent: ArticleWebView

        private var navigationType: WKNavigationType = .other

        init(_ parent: ArticleWebView) {
            self.parent = parent
        }

        private func shouldHandleDownloadForMimeType(_ mimeType: String) -> Bool {
            // MARK: TODO: more mime types for download tasks.
            let downloadableMimeTypes: [String] = ["application/pdf", "image/jpeg", "image/png"]
            return downloadableMimeTypes.contains(mimeType)
        }

        private func isValidatedLink(_ url: URL) -> Bool {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if components?.scheme == "http" || components?.scheme == "https" {
                return true
            }
            return false
        }

        private func moveDownloadedFile(_ download: WKDownload) {

        }

        // MARK: - NavigationDelegate

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

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            // handle (ignore) target="_blank" (open in new window) link as external
            if navigationAction.targetFrame == nil, let externalURL = navigationAction.request.url, isValidatedLink(externalURL) {
                NSWorkspace.shared.open(externalURL)
                decisionHandler(.cancel, preferences)
                return
            } else {
                if navigationAction.shouldPerformDownload {
                    decisionHandler(.download, preferences)
                } else {
                    decisionHandler(.allow, preferences)
                }
            }
            navigationType = navigationAction.navigationType
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.canShowMIMEType, let url = navigationResponse.response.url, let mimeType = navigationResponse.response.mimeType {
                if shouldHandleDownloadForMimeType(mimeType) {
                    decisionHandler(.download)
                } else {
                    if navigationType == .linkActivated, isValidatedLink(url) {
                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
                    decisionHandler(.allow)
                }
            } else {
                decisionHandler(.download)
            }
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            // MARK: TODO: detect running downloads before start new one.
            download.delegate = self
        }

        // MARK: - DownloadDelegate

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let downloadsDir = tempDir.appendingPathComponent("Downloads")
            if !FileManager.default.fileExists(atPath: downloadsDir.path) {
                try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
            }
            let downloadURL = downloadsDir.appendingPathComponent(suggestedFilename)
            if FileManager.default.fileExists(atPath: downloadURL.path) {
                if let userDownloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                    let downloadedURL = userDownloadsDir.appendingPathComponent(suggestedFilename)
                    try? FileManager.default.moveItem(at: downloadURL, to: downloadedURL)
                    NSWorkspace.shared.activateFileViewerSelecting([downloadedURL])
                }
                completionHandler(nil)
            } else {
                let downloadItem = PlanetDownloadItem(id: UUID(), created: Date(), download: download)
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
            if let url = download.progress.fileURL, let userDownloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                let downloadedURL = userDownloadsDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.moveItem(at: url, to: downloadedURL)
                NSWorkspace.shared.activateFileViewerSelecting([downloadedURL])
            }
        }

        func download(_ download: WKDownload, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(.performDefaultHandling, nil)
        }

        func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
