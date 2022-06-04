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

    var indexPath: URL {
        path.appendingPathComponent("templates", isDirectory: true)
            .appendingPathComponent("index.html", isDirectory: false)
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
            "assets_prefix": "../",
            "article": article,
            "page_title": article.title!,
            "content_html": content_html,
            "build_timestamp": Int(Date().timeIntervalSince1970)
        ]
        let loader = FileSystemLoader(paths: [Path(blogPath.deletingLastPathComponent().path)])
        let environment = Environment(loader: loader, extensions: [StencilExtension.get()])
        let stencilTemplateName = blogPath.lastPathComponent
        return try environment.renderTemplate(name: stencilTemplateName, context: context)
    }

    func renderIndex(articles: [PlanetArticle], planet: Planet) throws -> String {
        let sortedArticles = articles.sorted { a1, a2 in
            a1.created! > a2.created!
        }
        let context: [String: Any] = [
            "assets_prefix": "./",
            "page_title": planet.name!,
            "page_description": planet.about!,
            "articles": sortedArticles
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

        let title: String = "Template Preview \(name)"
        let content: String = """
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
"""
        let article = PlanetArticlePlaceholder(title: title, content: content)

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
