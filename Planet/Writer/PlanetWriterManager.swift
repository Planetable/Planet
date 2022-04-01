//
//  PlanetWriterManager.swift
//  Planet
//
//  Created by Kai on 3/29/22.
//

import Foundation
import SwiftUI
import Stencil
import PathKit
import Ink


class PlanetWriterManager: NSObject {
    static let shared = PlanetWriterManager()

    let previewEnv: Stencil.Environment
    let outputEnv: Stencil.Environment
    var articleTemplateName: String
    var writerTemplateName: String

    override init() {
        let basicTemplatePath = Bundle.main.url(forResource: "Basic", withExtension: "html")!
        let previewTemplatePath = Bundle.main.url(forResource: "WriterBasic", withExtension: "html")!
        previewEnv = Environment(loader: FileSystemLoader(paths: [Path(previewTemplatePath.path)]))
        outputEnv = Environment(loader: FileSystemLoader(paths: [Path(basicTemplatePath.path)]))
        writerTemplateName = previewTemplatePath.path
        articleTemplateName = basicTemplatePath.path
    }

    func renderHTML(fromContent c: String) -> String {
        let parser = MarkdownParser()
        let output = parser.html(from: c)
        return output
    }

    func renderPreview(content: String, forDocument id: UUID) -> URL? {
        debugPrint("rendering preview: \(content), document id: \(id) ...")
        do {
            let output = try previewEnv.renderTemplate(name: writerTemplateName, context: ["content_html": content])
            let draftPath = articleDraftPath(articleID: id)
            let targetPath = draftPath.appendingPathComponent("preview.html")
            try output.data(using: .utf8)?.write(to: targetPath)
            NotificationCenter.default.post(name: .reloadPage, object: targetPath)
            return targetPath
        } catch {
            debugPrint("failed to render preview: \(content), error: \(error)")
            return nil
        }
    }

    func createArticle(withArticleID id: UUID, forPlanet planetID: UUID, title: String, content: String) {
        let dataController = PlanetDataController.shared
        guard let planet = dataController.getPlanet(id: planetID) else { return }
        let context = dataController.persistentContainer.newBackgroundContext()
        let article = PlanetArticle(context: context)
        article.id = id
        article.planetID = planetID
        article.title = title
        article.content = content
        article.link = "/\(id.uuidString)/"
        article.created = Date()
        if planet.isMyPlanet() {
            article.isRead = true
        }
        do {
            try context.save()
            if planet.isMyPlanet(), let articlePath = articlePath(articleID: id, planetID: planetID) {
                // render article with default template
                let html = renderHTML(fromContent: content)
                let output = try outputEnv.renderTemplate(name: articleTemplateName, context: ["article": article, "content_html": html])
                let articleIndexPath = articlePath.appendingPathComponent("index.html")
                try output.data(using: .utf8)?.write(to: articleIndexPath)

                // generate article.json
                let articleJSONPath = articlePath.appendingPathComponent("article.json")
                let encoder = JSONEncoder()
                let data = try encoder.encode(article)
                try data.write(to: articleJSONPath)

                // publish
                Task.init(priority: .background) {
                    await PlanetManager.shared.publishForPlanet(planet: planet)
                }
            }
        } catch {
            debugPrint("failed to create new article: \(article), error: \(error)")
        }
    }

    func articlePath(articleID: UUID, planetID: UUID) -> URL? {
        let path = _planetsPath().appendingPathComponent(planetID.uuidString).appendingPathComponent(articleID.uuidString)
        if FileManager.default.fileExists(atPath: path.path) {
            return path
        }
        return nil
    }

    func setupArticlePath(articleID: UUID, planetID: UUID) {
        let path = _planetsPath().appendingPathComponent(planetID.uuidString)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.createDirectory(at: path.appendingPathComponent(articleID.uuidString), withIntermediateDirectories: true, attributes: nil)
    }

    func articleDraftPath(articleID: UUID) -> URL {
        let path = _draftPath().appendingPathComponent(articleID.uuidString)
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }

    // MARK: -
    @MainActor
    func launchWriter(forPlanet planet: Planet) {
        let articleID = planet.id!

        if PlanetStore.shared.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                PlanetStore.shared.activeWriterID = articleID
            }
            return
        }

        let writerView = PlanetWriterView(articleID: articleID)
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 720, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func launchWriter(forArticle article: PlanetArticle) {
        let articleID = article.id!

        if PlanetStore.shared.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                PlanetStore.shared.activeWriterID = articleID
            }
            return
        }
        let writerView = PlanetWriterEditView(articleID: articleID, title: article.title ?? "", content: article.content ?? "")
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 600, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: -
    private func _applicationSupportPath() -> URL? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private func _basePath() -> URL {
#if DEBUG
        let bundleID = Bundle.main.bundleIdentifier! + ".v03"
#else
        let bundleID = Bundle.main.bundleIdentifier! + ".v03"
#endif
        let path: URL
        if let p = _applicationSupportPath() {
            path = p.appendingPathComponent(bundleID, isDirectory: true)
        } else {
            path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Planet")
        }
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }

    private func _planetsPath() -> URL {
        let contentPath = _basePath().appendingPathComponent("planets", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }

    private func _draftPath() -> URL {
        let contentPath = _basePath().appendingPathComponent("drafts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }

    private func _templatesPath() -> URL {
        let contentPath = _basePath().appendingPathComponent("templates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }

}
