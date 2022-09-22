//
//  Template.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import Foundation
import Stencil
import PathKit
import os

class Template: Codable, Identifiable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Template")

    let name: String
    let description: String
    var path: URL! = nil
    let author: String
    let version: String

    var id: String { name }

    lazy var blogPath = path
        .appendingPathComponent("templates", isDirectory: true)
        .appendingPathComponent("blog.html", isDirectory: false)

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

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case author
        case version
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

    func render(article: MyArticleModel) throws -> String {
        // render markdown
        guard let content_html = CMarkRenderer.renderMarkdownHTML(markdown: article.content) else {
            throw PlanetError.RenderMarkdownError
        }

        let planet = article.planet!
        let publicPlanet = PublicPlanetModel(
            id: planet.id, name: planet.name, about: planet.about, ipns: planet.ipns, created: planet.created, updated: planet.updated, articles: [],
            plausibleEnabled: planet.plausibleEnabled ?? false,
            plausibleDomain: planet.plausibleDomain ?? nil,
            plausibleAPIServer: planet.plausibleAPIServer ?? "plausible.io",
            twitterUsername: planet.twitterUsername ?? nil,
            githubUsername: planet.githubUsername ?? nil
        )

        // render stencil template
        let context: [String: Any] = [
            "planet": publicPlanet,
            "planet_ipns": article.planet.ipns,
            "assets_prefix": "../",
            "article": article.publicArticle,
            "article_title": article.title,
            "page_title": article.title,
            "content_html": content_html,
            "build_timestamp": Int(Date().timeIntervalSince1970),
            "style_css_sha256": styleCSSHash ?? "",
        ]
        let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.common])
        let stencilTemplateName = blogPath.lastPathComponent
        return try environment.renderTemplate(name: stencilTemplateName, context: context)
    }

    func renderIndex(context: [String: Any]) throws -> String {
        guard let planet = context["planet"] as? PublicPlanetModel else {
            throw PlanetError.RenderMarkdownError
        }
        let pageAboutHTML = CMarkRenderer.renderMarkdownHTML(markdown: planet.about) ?? planet.about
        var contextForRendering: [String: Any] = [
            "assets_prefix": "./",
            "page_title": planet.name,
            "page_description": planet.about,
            "page_description_html": pageAboutHTML,
            "articles": planet.articles,
            "build_timestamp": Int(Date().timeIntervalSince1970),
            "style_css_sha256": styleCSSHash ?? "",
        ]
        for (key, value) in context {
            contextForRendering[key] = value
        }
        let loader = FileSystemLoader(paths: [Path(indexPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.common])
        let stencilTemplateName = indexPath.lastPathComponent
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

    func renderPreview() -> URL? {
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

        let articlePath = articleFolderPath.appendingPathComponent("blog.html")
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

                ---
                """,
            created: Date(),
            hasVideo: false,
            videoFilename: nil,
            hasAudio: false,
            audioFilename: nil,
            attachments: nil
        )

        // render markdown
        guard let content_html = CMarkRenderer.renderMarkdownHTML(markdown: article.content) else {
            return nil
        }

        // render stencil template
        let context: [String: Any] = [
            "assets_prefix": "../",
            "article": article,
            "content_html": content_html
        ]
        let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.common])
        let stencilTemplateName = blogPath.lastPathComponent
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
