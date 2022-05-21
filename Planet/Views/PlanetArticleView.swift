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

    var article: PlanetArticle?

    @State private var url: URL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!

    var body: some View {
        VStack {
                PlanetArticleWebView(url: $url)
                

                //    .task(priority: .utility) {
                //        if let urlPath = await PlanetManager.shared.articleURL(article: article!) {
                //            let now = Int(Date().timeIntervalSince1970)
                //            url = URL(string: urlPath.absoluteString + "?\(now)")!
                //            article!.isRead = true
                //            PlanetDataController.shared.save()
                //        } else {
                //            planetStore.currentArticle = nil
                //            PlanetManager.shared.alert(title: "Failed to load article", message: "Please try again later.")
                //        }
                //    }
        }
        .onChange(of: planetStore.currentArticle) { newArticle in
            Task.init {
                if let article = planetStore.currentArticle {
                    if let urlPath = await PlanetManager.shared.articleURL(article: article) {
                        url = URL(string: urlPath.absoluteString)!
                        article.isRead = true
                        PlanetDataController.shared.save()

                        NotificationCenter.default.post(name: .loadArticle, object: nil)
                    }
                }
            }
        }
        .onChange(of: planetStore.currentPlanet) { newPlanet in
            url = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
    }
}
