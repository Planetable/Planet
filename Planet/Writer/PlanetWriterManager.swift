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
            let draftPath = PlanetManager.shared.articleDraftPath(articleID: id)
            let targetPath = draftPath.appendingPathComponent("preview.html")
            try output.data(using: .utf8)?.write(to: targetPath)
            NotificationCenter.default.post(name: .reloadPage, object: targetPath)
            return targetPath
        } catch {
            debugPrint("failed to render preview: \(content), error: \(error)")
            return nil
        }
    }

    func createArticle(withArticleID id: UUID, forPlanet planetID: UUID, title: String, content: String) -> PlanetArticle? {
        let dataController = PlanetDataController.shared
        guard let planet = dataController.getPlanet(id: planetID) else { return nil }
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
            if planet.isMyPlanet(), let articlePath = PlanetManager.shared.articlePath(articleID: id, planetID: planetID) {
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
            return article
        } catch {
            debugPrint("failed to create new article: \(article), error: \(error)")
        }
        return nil
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

        let writerView = PlanetWriterView(articleID: articleID, isEditing: true, title: article.title ?? "", content: article.content ?? "")
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 720, 480), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }
}
