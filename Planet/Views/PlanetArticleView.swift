//
//  PlanetArticleView.swift
//  Planet
//
//  Created by Kai on 1/15/22.
//

import SwiftUI
import WebKit


struct PlanetArticleView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    var article: PlanetArticle

    @State private var url: URL = Bundle.main.url(forResource: "TemplatePlaceholder.html", withExtension: "")!

    var body: some View {
        VStack {
            if let currentArticleID = planetStore.currentArticle?.id, let id = article.id, id == currentArticleID {
                PlanetArticleWebView(url: $url)
                    .task(priority: .utility) {
                        if let urlPath = await PlanetManager.shared.articleURL(article: article) {
                            url = urlPath
                            article.isRead = true
                            PlanetDataController.shared.save()
                        } else {
                            planetStore.currentArticle = nil
                            PlanetManager.shared.alert(title: "Failed to load article", message: "Please try again later.")
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .refreshArticle, object: nil)) { n in
                        if let articleID = n.object as? UUID, let currentArticleID = article.id {
                            guard articleID == currentArticleID else { return }
                            Task.init(priority: .background) {
                                if let urlPath = await PlanetManager.shared.articleURL(article: article) {
                                    let now = Int(Date().timeIntervalSince1970)
                                    url = URL(string: urlPath.absoluteString + "?\(now)")!
                                } else {
                                    planetStore.currentArticle = nil
                                    PlanetManager.shared.alert(title: "Failed to load article", message: "Please try again later.")
                                }
                            }
                        }
                    }
            } else {
                Text("No Article Selected")
                    .foregroundColor(.secondary)
            }
        }
    }
}
