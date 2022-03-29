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

    let loader: FileSystemLoader
    let env: Stencil.Environment
    let templateName: String

    override init() {
        let previewTemplatePath = Bundle.main.url(forResource: "WriterBasic", withExtension: "html")!
        loader = FileSystemLoader(paths: [Path(previewTemplatePath.path)])
        env = Environment(loader: loader)
        templateName = previewTemplatePath.path
    }

    func renderHTML(fromContent c: String) -> String {
        let parser = MarkdownParser()
        let output = parser.html(from: c)
        return output
    }

    func renderPreview(content: String, forDocument id: UUID) -> URL? {
        debugPrint("rendering preview: \(content), document id: \(id) ...")
        do {
            let output = try env.renderTemplate(name: templateName, context: ["content_html": content])
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
