//
//  BackupArticleModel.swift
//  Planet
//
//  Created by Xin Liu on 8/12/23.
//

import Foundation

struct BackupArticleModel: Codable {
    let id: UUID
    let articleType: ArticleType?
    let link: String
    let slug: String?
    let heroImage: String?
    let heroImageWidth: Int?
    let heroImageHeight: Int?
    let externalLink: String?
    let title: String
    let content: String
    let contentRendered: String?
    let summary: String?
    let starred: Date?
    let starType: ArticleStarType
    let created: Date
    let videoFilename: String?
    let audioFilename: String?
    let attachments: [String]?
    let cids: [String: String]?
    let tags: [String: String]?
    let isIncludedInNavigation: Bool?
    let navigationWeight: Int?
    let originalSiteName: String?
    let originalSiteDomain: String?
    let originalPostID: String?
    let originalPostDate: Date?
    let pinned: Date?
}
