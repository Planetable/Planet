//
//  PlanetStore+Search.swift
//  Planet
//
//  Created by Xin Liu on 12/6/23.
//

import Foundation

extension PlanetStore {
    func searchArticles(text: String) async ->  [MyArticleModel] {
        var result: [MyArticleModel] = []
        let searchText = text.lowercased()
        if searchText.count == 0 {
            return result
        }
        for planet in myPlanets {
            for article in planet.articles {
                // Search in title, content
                // TODO: Also search in tags and slug
                if article.title.lowercased().contains(searchText) ||
                    article.content.lowercased().contains(searchText) {
                    result.append(article)
                }
            }
        }
        debugPrint("Search result for \(text): \(result.count)")
        return result
    }
}
