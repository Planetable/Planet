//
//  Template.swift
//  Planet
//
//  Created by Xin Liu on 5/3/22.
//

import Foundation
import Stencil
import PathKit
import os

struct TemplateSetting: Codable, Hashable, Identifiable {
    let name: String
    let type: String
    let defaultValue: String
    let description: String

    var id: String { name }
}

class Template: Codable, Identifiable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Template")

    let name: String
    let description: String
    var path: URL! = nil
    let author: String
    let version: String
    var idealItemsPerPage: Int? = 10
    var generateTagPages: Bool? = false
    var buildNumber: Int? = 1
    var generateNFTMetadata: Bool? = false
    var settings: [String: TemplateSetting]? = [:]

    var id: String { name }

    var hasSettings: Bool { settings?.count ?? 0 > 0 }

    lazy var blogPath = path
        .appendingPathComponent("templates", isDirectory: true)
        .appendingPathComponent("blog.html", isDirectory: false)

    // simple.html holds the basic minimal HTML structure for a quick preview.
    // It is not required for a template to have this file
    // TODO: A more detailed documentation about the template structure
    lazy var blogSimplePath = path
        .appendingPathComponent("templates", isDirectory: true)
        .appendingPathComponent("simple.html", isDirectory: false)

    // tags.html for tag cloud, not all templates have this file
    lazy var tagsPath = path
        .appendingPathComponent("templates", isDirectory: true)
        .appendingPathComponent("tags.html", isDirectory: false)

    lazy var indexPath = path
        .appendingPathComponent("templates", isDirectory: true)
        .appendingPathComponent("index.html", isDirectory: false)

    lazy var assetsPath = path.appendingPathComponent("assets", isDirectory: true)

    lazy var styleCSSPath = path
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("style.css", isDirectory: false)

    lazy var styleCSSHash: String? = {
        if let data = try? Data(contentsOf: styleCSSPath) {
            let hash = data.sha256().toHexString()
            debugPrint("style.css: \(data.count) bytes / sha256 -> \(hash)")
            return hash
        }
        return nil
    }()

    var hasGitRepo: Bool {
        let gitPath = path.appendingPathComponent(".git", isDirectory: true)
        return FileManager.default.fileExists(atPath: gitPath.path)
    }

    var hasSimpleHTML: Bool {
        return FileManager.default.fileExists(atPath: blogSimplePath.path)
    }

    var hasTagsHTML: Bool {
        return FileManager.default.fileExists(atPath: tagsPath.path)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case author
        case version
        case idealItemsPerPage
        case generateTagPages
        case buildNumber
        case generateNFTMetadata
        case settings
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        author = try container.decode(String.self, forKey: .author)
        version = try container.decode(String.self, forKey: .version)
        idealItemsPerPage = try container.decodeIfPresent(Int.self, forKey: .idealItemsPerPage)
        generateTagPages = try container.decodeIfPresent(Bool.self, forKey: .generateTagPages)
        buildNumber = try container.decodeIfPresent(Int.self, forKey: .buildNumber)
        generateNFTMetadata = try container.decodeIfPresent(Bool.self, forKey: .generateNFTMetadata)
        settings = try container.decodeIfPresent(Dictionary.self, forKey: .settings)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(author, forKey: .author)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(idealItemsPerPage, forKey: .idealItemsPerPage)
        try container.encodeIfPresent(generateTagPages, forKey: .generateTagPages)
        try container.encodeIfPresent(buildNumber, forKey: .buildNumber)
        try container.encodeIfPresent(generateNFTMetadata, forKey: .generateNFTMetadata)
        try container.encodeIfPresent(settings, forKey: .settings)
    }

    static func from(path: URL) -> Template? {
        let directoryName = path.lastPathComponent
        logger.info("Loading template at \(directoryName)")

        let templateInfoPath = path.appendingPathComponent("template.json")
        guard FileManager.default.fileExists(atPath: templateInfoPath.path) else {
            logger.error("Template directory \(directoryName) has no template.json")
            return nil
        }
        var template: Template
        do {
            let data = try Data(contentsOf: templateInfoPath)
            template = try JSONDecoder.shared.decode(Template.self, from: data)
            template.path = path
        } catch {
            logger.error("Unable to load template.json at \(directoryName)")
            return nil
        }
        guard FileManager.default.fileExists(atPath: template.blogPath.path) else {
            logger.error("Template directory \(directoryName) has no blog.html")
            return nil
        }
        guard FileManager.default.fileExists(atPath: template.assetsPath.path) else {
            logger.error("Template directory \(directoryName) has no assets directory")
            return nil
        }
        return template
    }

    func renderCustomCode(planet: MyPlanetModel, context: [String: Any]) -> [String: Any] {
        var output: [String: Any] = [
            "custom_code_head": "",
            "custom_code_body_start": "",
            "custom_code_body_end": ""
        ]
        if let customCodeHeadEnabled = planet.customCodeHeadEnabled, customCodeHeadEnabled, let customCodeHead: String = planet.customCodeHead {
            let template = Stencil.Template(templateString: customCodeHead)
            output["custom_code_head"] = try? template.render(context)
        }
        if let customCodeBodyStartEnabled = planet.customCodeBodyStartEnabled, customCodeBodyStartEnabled, let customCodeBodyStart: String = planet.customCodeBodyStart {
            let template = Stencil.Template(templateString: customCodeBodyStart)
            output["custom_code_body_start"] = try? template.render(context)
        }
        if let customCodeBodyEndEnabled = planet.customCodeBodyEndEnabled, customCodeBodyEndEnabled, let customCodeBodyEnd: String = planet.customCodeBodyEnd {
            let template = Stencil.Template(templateString: customCodeBodyEnd)
            output["custom_code_body_end"] = try? template.render(context)
        }
        return output
    }

    func render(article: MyArticleModel, forSimpleHTML: Bool = false) throws -> String {
        // render markdown
        guard let content_html = CMarkRenderer.renderMarkdownHTML(markdown: article.content) else {
            throw PlanetError.RenderMarkdownError
        }

        guard let planet = article.planet else {
            throw PlanetError.RenderMarkdownError
        }
        let publicPlanet = PublicPlanetModel(
            id: planet.id, name: planet.name, about: planet.about, ipns: planet.ipns, created: planet.created, updated: planet.updated, articles: [],
            plausibleEnabled: planet.plausibleEnabled ?? false,
            plausibleDomain: planet.plausibleDomain ?? nil,
            plausibleAPIServer: planet.plausibleAPIServer ?? "plausible.io",
            juiceboxEnabled: planet.juiceboxEnabled ?? false,
            juiceboxProjectID: planet.juiceboxProjectID,
            juiceboxProjectIDGoerli: planet.juiceboxProjectIDGoerli,
            twitterUsername: planet.twitterUsername ?? nil,
            githubUsername: planet.githubUsername ?? nil,
            telegramUsername: planet.telegramUsername ?? nil,
            mastodonUsername: planet.mastodonUsername ?? nil,
            podcastCategories: planet.podcastCategories ?? [:],
            podcastLanguage: planet.podcastLanguage ?? "en",
            podcastExplicit: planet.podcastExplicit ?? false,
            tags: planet.tags ?? [:]
        )
        let pageAboutHTML = CMarkRenderer.renderMarkdownHTML(markdown: planet.about) ?? planet.about

        // render stencil template
        var context: [String: Any] = [
            "page_description_html": pageAboutHTML,
            "planet": publicPlanet,
            "site_navigation": planet.siteNavigation(),
            "has_avatar": planet.hasAvatar(),
            "planet_ipns": article.planet.ipns,
            "assets_prefix": "../",
            "article_id": article.id.uuidString,
            "article": article.publicArticle,
            "article_type": article.articleType?.rawValue ?? 0,
            "article_title": article.title,
            "article_summary": article.summary ?? "",
            "page_title": article.title,
            "content_html": content_html,
            "build_timestamp": Int(Date().timeIntervalSince1970),
            "style_css_sha256": styleCSSHash ?? "",
            "current_item_type": "blog",
            "social_image_url": article.socialImageURL?.absoluteString ?? article.planet.ogImageURLString,
        ]
        context.merge(renderCustomCode(planet: planet, context: context)) { (_, new) in new }
        if (forSimpleHTML) {
            let loader = FileSystemLoader(paths: [Path(blogSimplePath.deletingLastPathComponent().path)])
            let environment = Environment(loader: loader, extensions: [StencilExtension.common])
            let stencilTemplateName = blogSimplePath.lastPathComponent
            return try environment.renderTemplate(name: stencilTemplateName, context: context)
        } else {
            let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
            let environment = Environment(loader: loader, extensions: [StencilExtension.common])
            let stencilTemplateName = blogPath.lastPathComponent
            return try environment.renderTemplate(name: stencilTemplateName, context: context)
        }
    }

    func getNextPage(page: Int, pages: Int) -> String? {
        if page < pages {
            return "page\(page + 1).html"
        }
        return nil
    }

    func getPreviousPage(page: Int, pages: Int) -> String? {
        if page > 1 {
            return "page\(page - 1).html"
        }
        return nil
    }

    func renderIndex(context: [String: Any]) throws -> String {
        guard let planet = context["planet"] as? PublicPlanetModel else {
            throw PlanetError.RenderMarkdownError
        }
        guard let myPlanet = context["my_planet"] as? MyPlanetModel else {
            throw PlanetError.RenderMarkdownError
        }
        let pageAboutHTML = CMarkRenderer.renderMarkdownHTML(markdown: planet.about) ?? planet.about
        var contextForRendering: [String: Any] = [
            "assets_prefix": "./",
            "page_title": planet.name,
            "page_description": planet.about,
            "page_description_html": pageAboutHTML,
            "articles": context["articles"] ?? [],
            "build_timestamp": Int(Date().timeIntervalSince1970),
            "style_css_sha256": styleCSSHash ?? "",
            "current_item_type": context["current_item_type"] ?? "index",
            "current_page": context["page"] ?? 1,
            "total_pages": context["pages"] ?? 1,
            "next_page": getNextPage(page: context["page"] as? Int ?? 1, pages: context["pages"] as? Int ?? 1) ?? nil,
            "previous_page": getPreviousPage(page: context["page"] as? Int ?? 1, pages: context["pages"] as? Int ?? 1) ?? nil,
        ]
        for (key, value) in context {
            contextForRendering[key] = value
        }
        contextForRendering.merge(renderCustomCode(planet: myPlanet, context: contextForRendering)) { (_, new) in new }
        let loader = FileSystemLoader(paths: [Path(indexPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.common])
        let stencilTemplateName = indexPath.lastPathComponent
        return try environment.renderTemplate(name: stencilTemplateName, context: contextForRendering)
    }

    func renderTags(context: [String: Any]) throws -> String {
        guard let planet = context["planet"] as? PublicPlanetModel else {
            throw PlanetError.RenderMarkdownError
        }
        guard let myPlanet = context["my_planet"] as? MyPlanetModel else {
            throw PlanetError.RenderMarkdownError
        }
        let pageAboutHTML = CMarkRenderer.renderMarkdownHTML(markdown: planet.about) ?? planet.about
        var contextForRendering: [String: Any] = [
            "assets_prefix": "./",
            "page_title": "\(planet.name) - Tags",
            "page_description": planet.about,
            "page_description_html": pageAboutHTML,
            "articles": context["articles"] ?? [],
            "build_timestamp": Int(Date().timeIntervalSince1970),
            "style_css_sha256": styleCSSHash ?? "",
            "current_item_type": "tags",
        ]
        for (key, value) in context {
            contextForRendering[key] = value
        }
        contextForRendering.merge(renderCustomCode(planet: myPlanet, context: contextForRendering)) { (_, new) in new }
        let loader = FileSystemLoader(paths: [Path(tagsPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.common])
        let stencilTemplateName = tagsPath.lastPathComponent
        return try environment.renderTemplate(name: stencilTemplateName, context: contextForRendering)
    }

    func prepareTemporaryAssetsForPreview() {
        let templatePreviewDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: templatePreviewDirectory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: templatePreviewDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                debugPrint("Failed to create template preview directory: \(error)")
            }
        }
        let assetsPreviewPath = templatePreviewDirectory.appendingPathComponent("assets", isDirectory: true)
        do {
            try? FileManager.default.removeItem(at: assetsPreviewPath)
            try FileManager.default.copyItem(at: assetsPath, to: assetsPreviewPath)
        } catch {
            debugPrint("Failed to prepare template preview assets: \(error)")
        }
    }

    func renderPreview(withPreviewIndex index: Int = 0) -> URL? {
        let templatePreviewDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        let assetsPreviewPath = templatePreviewDirectory.appendingPathComponent("assets", isDirectory: true)
        do {
            try? FileManager.default.removeItem(at: assetsPreviewPath)
            try FileManager.default.copyItem(at: assetsPath, to: assetsPreviewPath)
        } catch {
            debugPrint("Cannot copy template preview assets: \(error)")
        }

        let articleFolderPath = templatePreviewDirectory.appendingPathComponent("preview", isDirectory: true)
        if !FileManager.default.fileExists(atPath: articleFolderPath.path) {
            do {
                try FileManager.default.createDirectory(
                    at: articleFolderPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                debugPrint("Cannot create template preview directory: \(error)")
            }
        }

        let articlePath = articleFolderPath.appendingPathComponent(index == 1 ? "index.html" : "blog.html")
        let id = UUID()
        let article = PublicArticleModel(
            id: id,
            link: id.uuidString,
            title: "Template Preview \(name)",
            content:
                """
                Demo Article Content

                ### List

                - Item A
                - Item B
                - Item C

                ### Code Block

                ```python
                from flask import Flask

                app = Flask(__name__)

                @app.route("/")
                def hello_world():
                    return "<p>Hello, World!</p>"
                ```

                ### Blockquote

                > A dream you dream alone is only a dream. A dream you dream together is reality.

                ---

                | Header 1 | Header 2 |
                | --- | --- |
                | Row 1 Col 1 | Row 1 Col 2 |
                | Row 2 Col 1 | Row 2 Col 2 |
                """,
            created: Date(),
            hasVideo: false,
            videoFilename: nil,
            hasAudio: false,
            audioFilename: nil,
            audioDuration: nil,
            audioByteLength: nil,
            attachments: nil,
            heroImage: nil
        )

        // render markdown
        guard let content_html = CMarkRenderer.renderMarkdownHTML(markdown: article.content) else {
            return nil
        }

        let publicPlanet = PublicPlanetModel(
            id: UUID(),
            name: "Template Preview \(name)",
            about: "Template Preview \(name)",
            ipns: "k51",
            created: Date(),
            updated: Date(),
            articles: [article],
            plausibleEnabled: false,
            plausibleDomain: nil,
            plausibleAPIServer: nil,
            juiceboxEnabled: true,
            juiceboxProjectID: nil,
            juiceboxProjectIDGoerli: 207,
            twitterUsername: "PlanetableXYZ",
            githubUsername: "Planetable",
            telegramUsername: "",
            mastodonUsername: "",
            podcastCategories: [:],
            podcastLanguage: "en-US",
            podcastExplicit: false,
            tags: [:]
        )

        // render stencil template
        let context: [String: Any] = [
            "assets_prefix": "../",
            "article": article,
            "articles": [article],
            "content_html": content_html,
            "page_title": index == 1 ? self.name : article.title,
            "page_description": "Template preview for \(self.name)",
            "page_description_html": "Template preview for <strong>\(self.name)</strong>",
            "planet": publicPlanet
        ]
        let targetPath = index == 1 ? indexPath : blogPath
        let loader = FileSystemLoader(paths: [Path(targetPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.common])
        let stencilTemplateName = targetPath.lastPathComponent
        do {
            let output: String = try environment.renderTemplate(name: stencilTemplateName, context: context)
            try output.data(using: .utf8)?.write(to: articlePath)
            debugPrint("Preview article path: \(articlePath)")
            return articlePath
        } catch {
            debugPrint("Failed to render preview: \(error)")
            return nil
        }
    }
}
