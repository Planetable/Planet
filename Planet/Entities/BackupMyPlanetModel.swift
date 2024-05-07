//
//  BackupMyPlanetModel.swift
//  Planet
//
//  Created by Xin Liu on 8/12/23.
//

import Foundation

struct BackupMyPlanetModel: Codable {
    let id: UUID
    let name: String
    let about: String
    let domain: String?
    let authorName: String?
    let ipns: String
    let created: Date
    let updated: Date
    let lastPublished: Date?
    let lastPublishedCID: String?
    let archived: Bool?
    let archivedAt: Date?
    let templateName: String
    let plausibleEnabled: Bool?
    let plausibleDomain: String?
    let plausibleAPIKey: String?
    let plausibleAPIServer: String?
    let twitterUsername: String?
    let githubUsername: String?
    let telegramUsername: String?
    let mastodonUsername: String?
    let discordLink: String?
    let dWebServicesEnabled: Bool?
    let dWebServicesDomain: String?
    let dWebServicesAPIKey: String?
    let pinnableEnabled: Bool?
    let pinnableAPIEndpoint: String?
    let pinnablePinCID: String?
    let filebaseEnabled: Bool?
    let filebasePinName: String?
    let filebaseAPIToken: String?
    let filebaseRequestID: String?
    let filebasePinCID: String?
    let customCodeHeadEnabled: Bool?
    let customCodeHead: String?
    let customCodeBodyStartEnabled: Bool?
    let customCodeBodyStart: String?
    let customCodeBodyEndEnabled: Bool?
    let customCodeBodyEnd: String?
    let podcastCategories: [String: [String]]?
    let podcastLanguage: String?
    let podcastExplicit: Bool?
    let juiceboxEnabled: Bool?
    let juiceboxProjectID: Int?
    let juiceboxProjectIDGoerli: Int?
    let articles: [BackupArticleModel]
    let tags: [String: String]?
    let aggregation: [String]?
    let reuseOriginalID: Bool?
    let saveRoundAvatar: Bool?
    let doNotIndex: Bool?
    let prewarmNewPost: Bool?
}
