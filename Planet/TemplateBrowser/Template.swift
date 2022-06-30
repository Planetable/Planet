//
//  Template.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import Foundation
import Stencil
import PathKit
import Ink
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
        let publicArticle = PublicArticleModel(link: article.link,
                                               title: article.title,
                                               content: article.content,
                                               created: article.created)

        let result = MarkdownParser().parse(article.content)
        let content_html = result.html

        // render stencil template
        let context: [String: Any] = [
            "planet_ipns": article.planet.ipns,
            "assets_prefix": "../",
            "article": publicArticle,
            "article_title": publicArticle.title,
            "page_title": publicArticle.title,
            "content_html": content_html,
            "build_timestamp": Int(Date().timeIntervalSince1970),
        ]
        let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.get()])
        let stencilTemplateName = blogPath.lastPathComponent
        return try environment.renderTemplate(name: stencilTemplateName, context: context)
    }

    func renderIndex(planet: PublicPlanetModel) throws -> String {
        let context: [String: Any] = [
            "assets_prefix": "./",
            "page_title": planet.name,
            "page_description": planet.about,
            "articles": planet.articles,
            "build_timestamp": Int(Date().timeIntervalSince1970),
        ]
        let loader = FileSystemLoader(paths: [Path(indexPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.get()])
        let stencilTemplateName = indexPath.lastPathComponent
        return try environment.renderTemplate(name: stencilTemplateName, context: context)
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

        let article = PublicArticleModel(
            link: UUID().uuidString,
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
            created: Date()
        )

        // render markdown
        let result = MarkdownParser().parse(article.content)
        let content_html = result.html

        // render stencil template
        let context: [String: Any] = [
            "assets_prefix": "../",
            "article": article,
            "content_html": content_html
        ]
        let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.get()])
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
