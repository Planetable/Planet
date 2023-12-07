//
//  PlanetStore+Search.swift
//  Planet
//
//  Created by Xin Liu on 12/6/23.
//

import Foundation

extension PlanetStore {
    func searchArticles(text: String) async -> [MyArticleModel] {
        var result: [MyArticleModel] = []
        let searchText = text.lowercased()
        if searchText.count == 0 {
            return result
        }
        for planet in myPlanets {
            for article in planet.articles {
                if matchArticle(article: article, text: searchText) {
                    result.append(article)
                }
            }
        }
        debugPrint("Search result for \(text): \(result.count)")
        return result.sorted(by: { $0.created > $1.created })
    }

    private func matchArticle(article: MyArticleModel, text: String) -> Bool {
        let searchText = text.lowercased()
        if searchText.count == 0 {
            return false
        }
        if article.title.lowercased().contains(searchText) {
            return true
        }
        if article.content.lowercased().contains(searchText) {
            return true
        }
        if let slug = article.slug, slug.lowercased().contains(searchText) {
            return true
        }
        if let tags = article.tags,
            tags.keys.contains(where: { $0.lowercased().contains(searchText) })
        {
            return true
        }
        if let attachments = article.attachments,
            attachments.contains(where: { $0.lowercased().contains(searchText) })
        {
            return true
        }
        return false
    }
}
