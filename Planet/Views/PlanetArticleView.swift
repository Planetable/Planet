//
//  PlanetArticleView.swift
//  Planet
//
//  Created by Kai on 1/15/22.
//

import SwiftUI
import WebKit


class WebViewModel: ObservableObject {
    @Published var link: String
    @Published var didFinishLoading: Bool = false
    @Published var pageTitle: String
    
    init (link: String) {
        self.link = link
        self.pageTitle = ""
    }
}


struct SwiftUIWebView: NSViewRepresentable {
    
    public typealias NSViewType = WKWebView
    @ObservedObject var viewModel: WebViewModel

    private let webView: WKWebView = WKWebView()
    
    public func makeNSView(context: NSViewRepresentableContext<SwiftUIWebView>) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator as? WKUIDelegate
        webView.load(URLRequest(url: URL(string: viewModel.link)!))
        
        NotificationCenter.default.addObserver(forName: Notification.Name("SwiftUIWebViewReloadAction"), object: nil, queue: nil) { n in
            guard let url = n.object as? URL else { return }
            DispatchQueue.main.async {
                self.webView.load(URLRequest(url: URL(string: url.absoluteString)!, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 10))
            }
        }
        
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<SwiftUIWebView>) { }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(viewModel)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        private var viewModel: WebViewModel

        init(_ viewModel: WebViewModel) {
            self.viewModel = viewModel
        }
        
        public func webView(_: WKWebView, didFail: WKNavigation!, withError: Error) { }

        public func webView(_: WKWebView, didFailProvisionalNavigation: WKNavigation!, withError: Error) { }

        public func webView(_ web: WKWebView, didFinish: WKNavigation!) {
            let placeholderURL = Bundle.main.url(forResource: "TemplatePlaceholder.html", withExtension: "")
            self.viewModel.pageTitle = web.title!
            self.viewModel.link = web.url?.absoluteString ?? placeholderURL!.absoluteString
            self.viewModel.didFinishLoading = true
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}


struct SafariWebView: View {
    @ObservedObject var model: WebViewModel

    init(mesgURL: String) {
        self.model = WebViewModel(link: mesgURL)
    }
    
    var body: some View {
        SwiftUIWebView(viewModel: model)
    }
}


struct PlanetArticleView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    var article: PlanetArticle!

    var body: some View {
        VStack {
            if let article = article, let id = planetStore.selectedArticle, article.id != nil, id == article.id!.uuidString {
                let placeholderURL = Bundle.main.url(forResource: "TemplatePlaceholder.html", withExtension: "")
                SafariWebView(mesgURL: placeholderURL!.absoluteString)
                    .task(priority: .utility) {
                        if let urlPath = await PlanetManager.shared.articleURL(article: article) {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: Notification.Name("SwiftUIWebViewReloadAction"), object: urlPath)
                            }
                        }
                    }
            } else {
                Text("No Article Selected")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(planetStore.currentPlanet == nil ? "Planet" : planetStore.currentPlanet.name ?? "Planet")
    }
}
