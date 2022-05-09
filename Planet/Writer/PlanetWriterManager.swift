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

    let backupFileQueue: DispatchQueue

    override init() {
        let basicTemplatePath = Bundle.main.url(forResource: "Basic", withExtension: "html")!
        let previewTemplatePath = Bundle.main.url(forResource: "WriterBasic", withExtension: "html")!
        previewEnv = Environment(loader: FileSystemLoader(paths: [Path(previewTemplatePath.path)]))
        outputEnv = Environment(loader: FileSystemLoader(paths: [Path(basicTemplatePath.path)]))
        writerTemplateName = previewTemplatePath.path
        articleTemplateName = basicTemplatePath.path
        backupFileQueue = DispatchQueue.init(label: "planet.writer.backup.queue")
    }

    func renderHTML(fromContent c: String) -> String {
        let parser = MarkdownParser()
        let output = parser.html(from: c)
        return output
    }

    func renderPreview(content: String, forDocument id: UUID) -> URL? {
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

    func renderEditPreview(content: String, forDocument id: UUID, planetID: UUID) -> URL? {
        do {
            let output = try previewEnv.renderTemplate(name: writerTemplateName, context: ["content_html": content])
            let path = articlePath(articleID: id, planetID: planetID)!
            let targetPath = path.appendingPathComponent("preview.html")
            try output.data(using: .utf8)?.write(to: targetPath)
            NotificationCenter.default.post(name: .reloadPage, object: targetPath)
            return targetPath
        } catch {
            debugPrint("failed to render preview: \(content), error: \(error)")
            return nil
        }
    }

    func createArticle(withArticleID id: UUID, forPlanet planetID: UUID, title: String, content: String) -> PlanetArticle {
        let dataController = PlanetDataController.shared
        let planet = dataController.getPlanet(id: planetID)!
        let context = dataController.persistentContainer.viewContext
        let article = PlanetArticle(context: context)
        article.id = id
        article.planetID = planetID
        article.title = title
        article.content = content
        article.link = "/\(id.uuidString)/"
        article.created = Date()
        article.isRead = planet.isMyPlanet()
        if planet.isMyPlanet(), let articlePath = articlePath(articleID: id, planetID: planetID) {
            do {
                // render article with default template
                let html = renderHTML(fromContent: content)
                let output = try outputEnv.renderTemplate(name: articleTemplateName, context: ["article": article, "created_date": article.created!.ISO8601Format(), "content_html": html])
                let articleIndexPath = articlePath.appendingPathComponent("index.html")
                try output.data(using: .utf8)?.write(to: articleIndexPath)

                // generate article.json
                let articleJSONPath = articlePath.appendingPathComponent("article.json")
                let encoder = JSONEncoder()
                let data = try encoder.encode(article)
                try data.write(to: articleJSONPath)
            } catch {
                debugPrint("failed to save article: \(article): error: \(error)")
            }

            // publish
            Task.init(priority: .background) {
                await PlanetManager.shared.publish(planet)
            }
        }

        return article
    }

    func articlePath(articleID: UUID, planetID: UUID) -> URL? {
        let path = PlanetManager.shared.planetsPath.appendingPathComponent(planetID.uuidString).appendingPathComponent(articleID.uuidString)
        if FileManager.default.fileExists(atPath: path.path) {
            return path
        }
        return nil
    }

    func setupArticlePath(articleID: UUID, planetID: UUID) {
        let path = PlanetManager.shared.planetsPath.appendingPathComponent(planetID.uuidString)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.createDirectory(at: path.appendingPathComponent(articleID.uuidString), withIntermediateDirectories: true, attributes: nil)
    }

    func articleDraftPath(articleID: UUID) -> URL {
        let path = draftPath.appendingPathComponent(articleID.uuidString)
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }

    func copyDraft(articleID: UUID, toTargetPath targetPath: URL) {
        let draftPath = articleDraftPath(articleID: articleID)
        do {
            let previewContent = try String(contentsOf: draftPath.appendingPathComponent("preview.html"), encoding: .utf8)
            let contentsToCopy: [URL] = try FileManager.default
                .contentsOfDirectory(at: draftPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                .filter { u in
                    _validateDraftFileToCopy(inArticlePreviewContent: previewContent, fileURL: u)
                }
            for u in contentsToCopy {
                try? FileManager.default.copyItem(at: u, to: targetPath.appendingPathComponent(u.lastPathComponent))
            }
        } catch {
            debugPrint("failed to copy files from draft path: \(draftPath), error: \(error)")
        }
    }

    func removeDraft(articleID: UUID) {
        let draftPath = articleDraftPath(articleID: articleID)
        do {
            try FileManager.default.removeItem(at: draftPath)
        } catch {
            debugPrint("failed to remove draft path: \(draftPath), error: \(error)")
        }
        Task.detached(priority: .background) {
            await MainActor.run {
                PlanetWriterViewModel.shared.removeAllUploadings(articleID: articleID)
            }
        }
    }

    func backupUploading(articleID: UUID, fileURL url: URL) throws {
        let draftPath = articleDraftPath(articleID: articleID)
        let targetPath = draftPath.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: targetPath)
        } catch {
            debugPrint("failed to backup file \(url) to \(targetPath), article: \(articleID), error: \(error)")
        }
    }
    
    func recoverDeletedUploading(articleID: UUID, planetID: UUID, fileURL url: URL) throws {
        let draftPath = articleDraftPath(articleID: articleID)
        guard let articlePath = articlePath(articleID: articleID, planetID: planetID) else { return }
        let filename = url.lastPathComponent
        let backupPath = draftPath.appendingPathComponent(filename)
        let targetPath = articlePath.appendingPathComponent(filename)
        do {
            try FileManager.default.moveItem(at: backupPath, to: targetPath)
        } catch {
            debugPrint("failed to recover file \(targetPath), from \(backupPath), article: \(articleID), planet: \(planetID), error: \(error)")
        }
    }

    func uploadingIsImageFile(fileURL url: URL) -> Bool {
        let fileExtension = url.pathExtension
        let isImage: Bool
        if ["jpg", "jpeg", "png", "tiff", "gif"].contains(fileExtension) {
            isImage = true
        } else {
            isImage = false
        }
        return isImage
    }

    func uploadingCreationDate(fileURL url: URL) -> Date {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), let modifiedDate = attrs[.modificationDate] as? Date {
            return modifiedDate
        }
        return Date()
    }

    func uploadedFiles(fromArticle articleID: UUID, planetID: UUID) -> [URL] {
        let excludedFileNames: [String] = ["index.html", "preview.html", "article.json"]
        if let articlePath = articlePath(articleID: articleID, planetID: planetID) {
            if let articleContents = try? FileManager.default.contentsOfDirectory(at: articlePath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter({ u in
                !u.hasDirectoryPath
            }) {
                return articleContents.filter({ u in
                    !excludedFileNames.contains(u.lastPathComponent)
                })
            }
        }
        return []
    }

    // MARK: -
    @MainActor
    func processUploadings(urls: [URL], targetID: UUID, insertURLs: Bool = false, inEditMode editMode: Bool = false) {
        Task.init {
            for u in urls {
                await _uploadFile(articleID: targetID, fileURL: u, inEditMode: editMode)
            }
            await PlanetWriterViewModel.shared.updateUploadings(articleID: targetID, urls: urls)
            guard insertURLs else { return }
            for u in urls {
                await _insertFile(articleID: targetID, fileURL: u)
            }
        }
    }

    @MainActor
    func launchWriter(forPlanet planet: Planet) {
        // Launch writer to create a new article of a planet
        // writerID == planet.id
        guard let id = planet.id else { return }

        if PlanetStore.shared.writerIDs.contains(id) {
            PlanetStore.shared.activeWriterID = id
            return
        }

        Task.detached(priority: .utility) {
            await MainActor.run {
                PlanetWriterViewModel.shared.removeAllUploadings(articleID: id)
                PlanetWriterViewModel.shared.updateEditings(articleID: id, planetID: id)
            }
        }

        let writerView = PlanetWriterView(withID: id)
        let writerWindow = PlanetWriterWindow(
                rect: NSMakeRect(0, 0, 720, 480),
                maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView],
                backingType: .buffered,
                deferMode: false,
                writerID: id
        )
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func launchWriter(forArticle article: PlanetArticle) {
        // Launch writer to edit an existing article
        // writerID == article.id
        guard let id = article.id, let planetID = article.planetID else { return }

        if PlanetStore.shared.writerIDs.contains(id) {
            PlanetStore.shared.activeWriterID = id
            return
        }

        Task.detached(priority: .utility) {
            await MainActor.run {
                PlanetWriterViewModel.shared.removeAllUploadings(articleID: id)
                PlanetWriterViewModel.shared.updateEditings(articleID: id, planetID: planetID)
            }
        }

        let writerView = PlanetWriterView(withID: id, inEditMode: true, articleTitle: article.title ?? "", articleContent: article.content ?? "", planetID: planetID)
        let writerWindow = PlanetWriterWindow(
                rect: NSMakeRect(0, 0, 720, 480),
                maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView],
                backingType: .buffered,
                deferMode: false,
                writerID: id
        )
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: -
    var draftPath: URL {
        let contentPath = PlanetManager.shared.basePath.appendingPathComponent("drafts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }

    private func _uploadFile(articleID: UUID, fileURL url: URL, inEditMode editMode: Bool = false) async {
        let fileName = url.lastPathComponent
        if editMode {
            if let planetID = PlanetDataController.shared.getArticle(id: articleID)?.planetID, let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet(), let planetArticlePath = articlePath(articleID: articleID, planetID: planetID) {
                let targetPath = planetArticlePath.appendingPathComponent(fileName)
                do {
                    try FileManager.default.copyItem(at: url, to: targetPath)
                } catch {
                    debugPrint("failed to upload file: \(url), to target path: \(targetPath), error: \(error)")
                }
            }
        } else {
            let draftPath = articleDraftPath(articleID: articleID)
            let targetPath = draftPath.appendingPathComponent(fileName)
            do {
                try FileManager.default.copyItem(at: url, to: targetPath)
                if let planetID = PlanetDataController.shared.getArticle(id: articleID)?.planetID, let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet(), let planetArticlePath = articlePath(articleID: articleID, planetID: planetID) {
                    try FileManager.default.copyItem(at: targetPath, to: planetArticlePath.appendingPathComponent(fileName))
                }
            } catch {
                debugPrint("failed to upload file: \(url), to target path: \(targetPath), error: \(error)")
            }
        }
    }

    private func _insertFile(articleID: UUID, fileURL url: URL) async {
        let filename = url.lastPathComponent
        let isImage = uploadingIsImageFile(fileURL: url)
        let c: String = (isImage ? "\n" : "") + (isImage ? "!" : "") + "[\(filename)]" + "(" + filename + ")"
        let n: Notification.Name = Notification.Name.notification(notification: .insertText, forID: articleID)
        await MainActor.run {
            NotificationCenter.default.post(name: n, object: c)
        }
    }

    private func _validateDraftFileToCopy(inArticlePreviewContent content: String, fileURL url: URL) -> Bool {
        let filename = url.lastPathComponent
        // ingore preview.html
        if filename.lowercased() == "preview.html" {
            return false
        }
        // ignore files not in article
        if !content.contains(filename) {
            return false
        }
        return true
    }
}
