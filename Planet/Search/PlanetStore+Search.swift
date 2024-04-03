//
//  PlanetStore+Search.swift
//  Planet
//
//  Created by Xin Liu on 12/6/23.
//

import Foundation

extension PlanetStore {
    func searchAllArticles(text: String) async -> [SearchResult] {
        guard !text.isEmpty else { return [] }

        let searchText = text.lowercased()

        // Use async let to concurrently perform the searches
        async let myPlanetResults = searchArticles(
            in: myPlanets,
            matching: searchText,
            planetKind: .my
        )
        async let followingPlanetResults = searchArticles(
            in: followingPlanets,
            matching: searchText,
            planetKind: .following
        )

        // Await the results of both searches and combine them
        let results = (await myPlanetResults) + (await followingPlanetResults)

        debugPrint("Search result for \(text): \(results.count)")
        return results.sorted(by: { $0.articleCreated > $1.articleCreated })
    }

    private func searchArticles(
        in planets: [MyPlanetModel],
        matching text: String,
        planetKind: PlanetKind
    ) async -> [SearchResult] {
        await withTaskGroup(of: [SearchResult].self, returning: [SearchResult].self) { group in
            for planet in planets {
                group.addTask {
                    var matches: [SearchResult] = []
                    for article in planet.articles {
                        let isMatch = await self.matchMyArticle(article: article, text: text)
                        if isMatch {
                            let match = SearchResult(
                                articleID: article.id,
                                articleCreated: article.created,
                                title: article.title,
                                preview: article.content,
                                planetID: planet.id,
                                planetName: planet.name,
                                planetKind: planetKind
                            )
                            matches.append(match)
                        }
                    }
                    return matches
                }
            }
            // Collect results from all tasks
            let allResults = await group.reduce(into: []) { $0 += $1 }

            // Sort if needed or apply any criteria for determining 'top' results
            // This step is optional and can be adjusted based on how you define 'top'
            // For example, you might sort by articleCreated date or any other relevant field
            // allResults.sort(by: { $0.articleCreated > $1.articleCreated })

            // Return only the top 200 results
            return Array(allResults.prefix(200))
        }
    }

    private func searchArticles(
        in planets: [FollowingPlanetModel],
        matching text: String,
        planetKind: PlanetKind
    ) async -> [SearchResult] {
        await withTaskGroup(of: [SearchResult].self, returning: [SearchResult].self) { group in
            for planet in planets {
                group.addTask {
                    var matches: [SearchResult] = []
                    for article in planet.articles {
                        let isMatch = await self.matchFollowingArticle(article: article, text: text)
                        if isMatch {
                            let match = SearchResult(
                                articleID: article.id,
                                articleCreated: article.created,
                                title: article.title,
                                preview: article.content,
                                planetID: planet.id,
                                planetName: planet.name,
                                planetKind: planetKind
                            )
                            matches.append(match)
                        }
                    }
                    return matches
                }
            }
            // Collect results from all tasks
            var allResults = await group.reduce(into: []) { $0 += $1 }

            // Optionally sort the results if you have a specific criterion for 'top' results
            // allResults.sort(by: { $0.articleCreated > $1.articleCreated })

            // Return only the top 200 results
            return Array(allResults.prefix(200))
        }
    }

    private func matchMyArticle(article: MyArticleModel, text: String) async -> Bool {
        let searchText = text.lowercased()
        guard searchText.count > 0 else {
            return false
        }

        // Use a task group to check article title, content, slug, tags, and attachments in parallel
        return await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            // Check title
            group.addTask {
                return article.title.lowercased().contains(searchText)
            }

            // Check content
            group.addTask {
                return article.content.lowercased().contains(searchText)
            }

            // Check slug, if it exists
            if let slug = article.slug {
                group.addTask {
                    return slug.lowercased().contains(searchText)
                }
            }

            // Check tags, if they exist
            if let tags = article.tags {
                group.addTask {
                    return tags.keys.contains(where: { $0.lowercased().contains(searchText) })
                }
            }

            // Check attachments, if they exist
            if let attachments = article.attachments {
                group.addTask {
                    return attachments.contains(where: { $0.lowercased().contains(searchText) })
                }
            }

            // Iterate over the results, returning true if any task finds a match
            for await result in group {
                if result {
                    return true
                }
            }

            // If none of the tasks returned true, then there was no match
            return false
        }
    }

    private func matchFollowingArticle(article: FollowingArticleModel, text: String) async -> Bool {
        let searchText = text.lowercased()
        guard searchText.count > 0 else {
            return false
        }

        // Use a task group to check article title, content, and attachments in parallel
        return await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            // Check title
            group.addTask {
                return article.title.lowercased().contains(searchText)
            }

            // Check content
            group.addTask {
                return article.content.lowercased().contains(searchText)
            }

            // Check attachments, if they exist
            if let attachments = article.attachments {
                group.addTask {
                    return attachments.contains(where: { $0.lowercased().contains(searchText) })
                }
            }

            // Iterate over the results, returning true if any task finds a match
            for await result in group {
                if result {
                    return true
                }
            }

            // If none of the tasks returned true, then there was no match
            return false
        }
    }
}
