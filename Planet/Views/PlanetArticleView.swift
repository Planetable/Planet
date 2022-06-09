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

    @State private var url: URL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!

    var body: some View {
        VStack {
            PlanetArticleWebView(url: $url)
        }
        .background(
            Color(NSColor.textBackgroundColor)
        )
        .onChange(of: planetStore.currentArticle) { newArticle in
            Task.init {
                if let article = planetStore.currentArticle {
                    if let articleURL = await PlanetManager.shared.articleURL(article: article) {
                        url = articleURL
                        article.isRead = true
                        PlanetDataController.shared.save()

                        NotificationCenter.default.post(name: .loadArticle, object: nil)
                    }
                } else {
                    url = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
                    NotificationCenter.default.post(name: .loadArticle, object: nil)
                }
            }
        }
        .onChange(of: planetStore.currentPlanet) { newPlanet in
            url = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
    }
}
