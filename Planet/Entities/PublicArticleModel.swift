//
//  PublicArticleModel.swift
//  Planet
//
//  Created by Xin Liu on 8/12/23.
//

import Foundation

struct PublicArticleModel: Codable {
    var articleType: ArticleType? = .blog
    let id: UUID
    let link: String
    var slug: String? = ""
    var externalLink: String? = ""
    let title: String
    let content: String
    let contentRendered: String?
    let created: Date
    let hasVideo: Bool?
    let videoFilename: String?
    let hasAudio: Bool?
    let audioFilename: String?
    let audioDuration: Int?
    let audioByteLength: Int?
    let attachments: [String]?
    let heroImage: String?
    let heroImageURL: String?
    let heroImageFilename: String?
    var cids: [String: String]? = [:]
    var tags: [String: String]? = [:]
    var originalSiteName: String? = nil
    var originalSiteDomain: String? = nil
    var originalPostID: String? = nil
    var originalPostDate: Date? = nil
    var pinned: Date? = nil
}
