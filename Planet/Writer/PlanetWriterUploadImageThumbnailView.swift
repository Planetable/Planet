//
//  PlanetWriterUploadImageThumbnailView.swift
//  Planet
//
//  Created by Kai on 3/30/22.
//

import SwiftUI


struct PlanetWriterUploadImageThumbnailView: View {
    var articleID: UUID
    var fileURL: URL
    @Binding var sourceFiles: Set<URL>
    @State private var isShowingPlusIcon: Bool = false

    var body: some View {
        ZStack {
            thumbnailFromFile()
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40, alignment: .center)
                .padding(.top, 2)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                    Spacer()
                }
                Spacer()
            }
            .padding(4)
            .onTapGesture {
                insertFile()
            }

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                        .onTapGesture {
                            deleteFile()
                        }
                }
                Spacer()
            }
            .padding(.leading, 0)
            .padding(.top, 2)
            .padding(.trailing, -8)
        }
        .frame(width: 44, height: 44, alignment: .center)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .onHover { isHovering in
            withAnimation {
                isShowingPlusIcon = isHovering
            }
        }
    }

    private func _getCharacters(fromContent content: String) -> [Character] {
        var cc = [Character]()
        for c in content {
            cc.append(c)
        }
        return cc
    }

    private func getUploadedFile() -> (isImage: Bool, uploadURL: URL?) {
        let filename = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension
        let isImage: Bool
        if ["jpg", "jpeg", "png", "pdf", "tiff", "gif"].contains(fileExtension) {
            isImage = true
        } else {
            isImage = false
        }

        var filePath: URL?
        if let planetID = PlanetDataController.shared.getArticle(id: articleID)?.planetID {
            if let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet() {
                if let planetArticlePath = PlanetManager.shared.articlePath(articleID: articleID, planetID: planetID) {
                    if FileManager.default.fileExists(atPath: planetArticlePath.appendingPathComponent(filename).path) {
                        filePath = planetArticlePath.appendingPathComponent(filename)
                    }
                }
            }
        }

        // if not exists, find in draft directory:
        let draftPath = PlanetManager.shared.articleDraftPath(articleID: articleID)
        let draftFilePath = draftPath.appendingPathComponent(filename)
        if filePath == nil, FileManager.default.fileExists(atPath: draftFilePath.path) {
            filePath = draftFilePath
        }

        return (isImage, filePath)
    }

    private func deleteFile() {
        debugPrint("deleting file: \(fileURL)")
        let uploaded = getUploadedFile()
        guard let filePath = uploaded.uploadURL else { return }
        do {
            try FileManager.default.removeItem(at: filePath)
            sourceFiles = sourceFiles.filter { u in
                return u != fileURL
            }
        } catch {
            debugPrint("failed to delete uploaded file: \(fileURL), error: \(error)")
        }
        let filename = filePath.lastPathComponent
        let c: String = (uploaded.isImage ? "!" : "") + "[\(filename)]" + "(" + filename + ")"
        let n: Notification.Name = Notification.Name.notification(notification: .removeText, forID: articleID)
        NotificationCenter.default.post(name: n, object: c)
    }

    private func insertFile() {
        debugPrint("inserting file: \(fileURL) ...")
        let uploaded = getUploadedFile()
        guard let filePath = uploaded.uploadURL else { return }
        let filename = filePath.lastPathComponent
        let c: String = (uploaded.isImage ? "!" : "") + "[\(filename)]" + "(" + filename + ")"
        let n: Notification.Name = Notification.Name.notification(notification: .insertText, forID: articleID)
        NotificationCenter.default.post(name: n, object: c)
    }

    private func thumbnailFromFile() -> Image {
        // check file locations
        let size = NSSize(width: 80, height: 80)
        let filename = fileURL.lastPathComponent

        // find in planet directory:
        if let planetID = PlanetDataController.shared.getArticle(id: articleID)?.planetID {
            if let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet() {
                if let planetArticlePath = PlanetManager.shared.articlePath(articleID: articleID, planetID: planetID) {
                    if FileManager.default.fileExists(atPath: planetArticlePath.appendingPathComponent(filename).path) {
                        if let img = NSImage(contentsOf: planetArticlePath.appendingPathComponent(filename)), let resizedImg = img.imageResize(size) {
                            return Image(nsImage: resizedImg)
                        }
                    }
                }
            }
        }

        // if not exists, find in draft directory:
        let draftPath = PlanetManager.shared.articleDraftPath(articleID: articleID)
        let imagePath = draftPath.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: imagePath.path) {
            if let img = NSImage(contentsOf: imagePath), let resizedImg = img.imageResize(size) {
                return Image(nsImage: resizedImg)
            }
        }

        return Image(systemName: "questionmark.app.dashed")
    }
}
