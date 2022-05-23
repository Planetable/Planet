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

struct Template: Codable, Identifiable, Hashable {
    var name: String
    var id: String { "\(name)" }
    var description: String
    var path: URL!
    var author: String
    var version: String

    var blogPath: URL {
        path.appendingPathComponent("templates", isDirectory: true)
            .appendingPathComponent("blog.html", isDirectory: false)
    }
    var assetsPath: URL {
        path.appendingPathComponent("assets", isDirectory: true)
    }

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

    static func from(url: URL) -> Template? {
        let templateInfoPath = url.appendingPathComponent("template.json")
        if !FileManager.default.fileExists(atPath: templateInfoPath.path) {
            return nil
        }
        var template: Template
        do {
            let data = try Data(contentsOf: templateInfoPath)
            let decoder = JSONDecoder()
            template = try decoder.decode(Template.self, from: data)
            template.path = url
        } catch {
            debugPrint("Failed to load template info for \(url.lastPathComponent)")
            return nil
        }
        if !FileManager.default.fileExists(atPath: template.blogPath.path) {
            debugPrint("Directory has no blog.html: \(url.path)")
            return nil
        }
        if !FileManager.default.fileExists(atPath: template.assetsPath.path) {
            debugPrint("Directory has no assets directory: \(url.path)")
            return nil
        }
        return template
    }

    func render(article: PlanetArticle) throws -> String {
        // render markdown
        let result = MarkdownParser().parse(article.content!)
        let content_html = result.html

        // render stencil template
        let context: [String: Any] = [
            "article": article,
            "created_date": article.created!.ISO8601Format(),
            "content_html": content_html
        ]
        let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader)
        let stencilTemplateName = blogPath.lastPathComponent
        return try environment.renderTemplate(name: stencilTemplateName, context: context)
    }

    func renderPreview() -> URL? {
        let templateFolder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        let assetsFolderPath = templateFolder.appendingPathComponent("assets", isDirectory: true)
        if !FileManager.default.fileExists(atPath: assetsFolderPath.path) {
            do {
                try FileManager.default.createSymbolicLink(at: assetsFolderPath, withDestinationURL: assetsPath)
            } catch {
                debugPrint("Cannot link template preview assets: \(error)")
            }
        }

        let articleFolderPath = templateFolder.appendingPathComponent("preview", isDirectory: true)
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

        let title: String = "Template Preview \(name)"
        let article = PlanetArticlePlaceholder(title: title, content: "Demo Article Content")

        // render markdown
        let result = MarkdownParser().parse(article.content)
        let content_html = result.html

        // render stencil template
        let context: [String: Any] = [
            "article": article,
            "created_date": article.created.ISO8601Format(),
            "content_html": content_html
        ]
        let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader)
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
