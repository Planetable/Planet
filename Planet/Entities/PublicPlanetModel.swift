//
//  PublicPlanetModel.swift
//  Planet
//
//  Created by Xin Liu on 8/12/23.
//

import Foundation

struct PublicPlanetModel: Codable {
    let id: UUID
    let name: String
    let about: String
    let ipns: String
    let created: Date
    let updated: Date
    let articles: [PublicArticleModel]

    let plausibleEnabled: Bool?
    let plausibleDomain: String?
    let plausibleAPIServer: String?

    let juiceboxEnabled: Bool?
    let juiceboxProjectID: Int?
    let juiceboxProjectIDGoerli: Int?

    let twitterUsername: String?
    let githubUsername: String?
    let telegramUsername: String?
    let mastodonUsername: String?
    let discordLink: String?

    let podcastCategories: [String: [String]]?
    let podcastLanguage: String?
    let podcastExplicit: Bool?

    let tags: [String: String]?

    func hasAudioContent() -> Bool {
        for article in articles {
            if article.audioFilename != nil {
                return true
            }
        }
        return false
    }

    func hasVideoContent() -> Bool {
        for article in articles {
            if article.videoFilename != nil {
                return true
            }
        }
        return false
    }
}
