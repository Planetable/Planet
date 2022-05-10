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
                PlanetArticleWebView(url: $url, targetID: id)
                    .task(priority: .utility) {
                        if let urlPath = await PlanetManager.shared.articleURL(article: article) {
                            let now = Int(Date().timeIntervalSince1970)
                            url = URL(string: urlPath.absoluteString + "?\(now)")!
                            article.isRead = true
                            PlanetDataController.shared.save()
                        } else {
                            planetStore.currentArticle = nil
                            PlanetManager.shared.alert(title: "Failed to load article", message: "Please try again later.")
                        }
                    }
            } else {
                Text("No Article Selected")
                    .foregroundColor(.secondary)
            }
        }
    }
}
