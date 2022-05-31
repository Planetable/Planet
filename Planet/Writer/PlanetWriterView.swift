//
//  PlanetWriterView.swift
//  Planet
//
//  Created by Kai on 2/22/22.
//

import SwiftUI
import Stencil
import PathKit
import WebKit
import Ink


struct PlanetWriterView: View {
    var targetID: UUID
    var isEditing: Bool

    var originalPlanetID: UUID
    var originalTitle: String
    var originalContent: String
    var originalUploadings: [URL]

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var htmlContent: String = ""

    @State private var previewPath: URL!

    @State private var isToolBoxOpen: Bool = true
    @State private var isPreviewOpen: Bool = true
    @State private var selectedRanges: [NSValue] = []

    @ObservedObject private var viewModel: PlanetWriterViewModel

    init(withID id: UUID, inEditMode editMode: Bool = false, articleTitle: String = "", articleContent: String = "", planetID: UUID = UUID()) {
        targetID = id
        isEditing = editMode
        originalPlanetID = planetID
        originalTitle = articleTitle
        originalContent = articleContent
        originalUploadings = PlanetWriterManager.shared.uploadedFiles(fromArticle: id, planetID: planetID)
        _viewModel = ObservedObject(wrappedValue: PlanetWriterViewModel.shared)
    }

    var body: some View {
        VStack (spacing: 0) {
            HStack (spacing: 0) {
                TextField("Title", text: $title)
                    .frame(height: 34, alignment: .leading)
                    .padding(.bottom, 2)
                    .padding(.horizontal, 16)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .background(.clear)
                    .textFieldStyle(PlainTextFieldStyle())

                Spacer()

                HStack (spacing: 8) {
                    Button {
                        isToolBoxOpen.toggle()
                    } label: {
                        Label("ToolBox", systemImage: isToolBoxOpen ? "keyboard.fill" : "keyboard")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        isPreviewOpen.toggle()
                    } label: {
                        Label("Preview", systemImage: isPreviewOpen ? "doc.richtext.fill" : "doc.richtext")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.trailing, 16)
            }

            Divider()

            HSplitView {
                PlanetWriterTextView(text: $content, selectedRanges: $selectedRanges, writerID: targetID)
                    .frame(minWidth: PlanetWriterManager.windowMinWidth / 2.0,
                           maxWidth: .infinity,
                           minHeight: PlanetWriterManager.windowMinHeight,
                           maxHeight: .infinity)
                    .onChange(of: content) { newValue in
                        htmlContent = PlanetWriterManager.shared.renderHTML(fromContent: newValue)
                        Task.init(priority: .utility) {
                            if isEditing {
                                if let path = PlanetWriterManager.shared.renderEditPreview(content: htmlContent, forDocument: targetID, planetID: originalPlanetID) {
                                    if previewPath != path {
                                        previewPath = path
                                    }
                                }
                            } else {
                                if let path = PlanetWriterManager.shared.renderPreview(content: htmlContent, forDocument: targetID) {
                                    if previewPath != path {
                                        previewPath = path
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: selectedRanges) { [selectedRanges] newValue in
                        debugPrint("Ranges: \(selectedRanges) -->> \(newValue)")
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name.notification(notification: .rerenderPage, forID: targetID))) { n in
                        guard let deletedContent = n.object as? String else { return }
                        content = content.replacingOccurrences(of: deletedContent, with: "")
                    }
                if isPreviewOpen {
                    PlanetWriterPreviewView(url: previewPath, targetID: targetID)
                        .frame(minWidth: PlanetWriterManager.windowMinWidth / 2.0,
                               maxWidth: .infinity,
                               minHeight: PlanetWriterManager.windowMinHeight,
                               maxHeight: .infinity)
                }
            }

            if isToolBoxOpen {
                Divider()
                ScrollView(.horizontal) {
                    HStack (spacing: 0) {
                        Image(systemName: "plus.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30, alignment: .center)
                            .padding(.leading, 16)
                            .opacity(0.5)
                            .onTapGesture {
                                if let urls: [URL] = uploadImagesAction() {
                                    Task { @MainActor in
                                        PlanetWriterManager.shared.processUploadings(urls: urls, targetID: targetID, inEditMode: isEditing)
                                    }
                                }
                            }

                        if let uploadings: Set<URL> = viewModel.uploadings[targetID] {
                            ForEach(Array(uploadings).sorted { a, b in
                                return PlanetWriterManager.shared.uploadingCreationDate(fileURL: a) < PlanetWriterManager.shared.uploadingCreationDate(fileURL: b)
                            }, id: \.self) { fileURL in
                                PlanetWriterUploadImageThumbnailView(articleID: targetID, fileURL: fileURL)
                                    .environmentObject(viewModel)
                            }
                        }
                    }
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.03))
                .onDrop(of: [.fileURL], delegate: viewModel)
            }

            Divider()

            HStack {
                Button {
                    cancelAction()
                } label: {
                    Text("Cancel")
                }

                Spacer()

                Button {
                    if isEditing {
                        updateAction()
                    } else {
                        saveAction()
                    }
                } label: {
                    Text("Save")
                }
                .disabled(title.count == 0)
            }
            .padding(16)
        }
        .frame(minWidth: PlanetWriterManager.windowMinWidth)
        .onReceive(NotificationCenter.default.publisher(for: .closeWriterWindow, object: nil)) { n in
            guard let id = n.object as? UUID, id == targetID else { return }
            cancelAction()
        }
        .task {
            guard isEditing else { return }
            title = originalTitle
            content = originalContent
            selectedRanges = [NSValue(range: NSRange(location: content.count - 1, length: 0))]
            let c: Notification.Name = Notification.Name.notification(notification: .clearText, forID: targetID)
            let n: Notification.Name = Notification.Name.notification(notification: .insertText, forID: targetID)
            await MainActor.run {
                NotificationCenter.default.post(name: c, object: nil)
                NotificationCenter.default.post(name: n, object: originalContent)
            }
            await viewModel.updateUploadings(articleID: targetID, urls: originalUploadings)
        }
    }

    @MainActor
    private func cancelAction() {
        if PlanetStore.shared.writerIDs.contains(targetID) {
            PlanetStore.shared.writerIDs.remove(targetID)
        }
        if PlanetStore.shared.activeWriterID == targetID {
            PlanetStore.shared.activeWriterID = .init()
        }
        defer {
            PlanetWriterManager.shared.removeDraft(articleID: targetID)
            PlanetWriterViewModel.shared.removeEditings(articleID: targetID)
        }

        guard isEditing else { return }

        // remove preview.html
        if let targetPath = PlanetWriterManager.shared.articlePath(articleID: targetID, planetID: originalPlanetID) {
            let previewPath = targetPath.appendingPathComponent("preview.html")
            try? FileManager.default.removeItem(at: previewPath)
        }

        let uploadings = PlanetWriterManager.shared.uploadedFiles(fromArticle: targetID, planetID: originalPlanetID).sorted { a, b in
            return a.path < b.path
        }
        let originals = originalUploadings.sorted { a, b in
            return a.path < b.path
        }
        if uploadings.elementsEqual(originals) {
            debugPrint("No need to add or remove uploadings.")
            return
        }

        // remove added uploadings, recover removed uploadings.
        var added: Set<URL> = Set<URL>()
        for uploading in uploadings {
            if !originals.contains(uploading) {
                added.insert(uploading)
            }
        }
        var removed: Set<URL> = Set<URL>()
        for original in originals {
            if !uploadings.contains(original) {
                removed.insert(original)
            }
        }
        for add in added {
            do {
                try FileManager.default.removeItem(at: add)
            } catch {
                debugPrint("failed to delete added file: \(add), article: \(targetID), error: \(error)")
            }
        }
        for remove in removed {
            do {
                try PlanetWriterManager.shared.recoverDeletedUploading(articleID: targetID, planetID: originalPlanetID, fileURL: remove)
            } catch {
                debugPrint("failed to recover deleted file: \(remove), article: \(targetID), error: \(error)")
            }
        }
    }

    @MainActor
    private func saveAction() {
        // make sure current new article id equals to the planet id first, then generate new article id.
        let createdArticleID = UUID()

        PlanetWriterManager.shared.setupArticlePath(articleID: createdArticleID, planetID: targetID)
        if let targetPath = PlanetWriterManager.shared.articlePath(articleID: createdArticleID, planetID: targetID) {
            PlanetWriterManager.shared.copyDraft(articleID: targetID, toTargetPath: targetPath)
        }

        let article = PlanetWriterManager.shared.createArticle(withArticleID: createdArticleID, forPlanet: targetID, title: title, content: content)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PlanetStore.shared.currentArticle = article
        }

        if PlanetStore.shared.writerIDs.contains(targetID) {
            PlanetStore.shared.writerIDs.remove(targetID)
        }
        if PlanetStore.shared.activeWriterID == targetID {
            PlanetStore.shared.activeWriterID = .init()
        }
        PlanetWriterManager.shared.removeDraft(articleID: targetID)
    }

    @MainActor
    private func updateAction() {
        Task.init {
            try await PlanetDataController.shared.updateArticle(withID: targetID, title: title, content: content)
            if PlanetStore.shared.writerIDs.contains(targetID) {
                PlanetStore.shared.writerIDs.remove(targetID)
            }
            if PlanetStore.shared.activeWriterID == targetID {
                PlanetStore.shared.activeWriterID = .init()
            }
        }

        defer {
            // remove draft
            PlanetWriterManager.shared.removeDraft(articleID: targetID)
            PlanetWriterViewModel.shared.removeEditings(articleID: targetID)
        }

        // save updated article
        guard let article = PlanetDataController.shared.getArticle(id: targetID) else { return }
        article.title = title
        article.content = content
        PlanetDataController.shared.save()

        // remove preview.html
        if let targetPath = PlanetWriterManager.shared.articlePath(articleID: targetID, planetID: originalPlanetID) {
            let previewPath = targetPath.appendingPathComponent("preview.html")
            try? FileManager.default.removeItem(at: previewPath)
        }

        // publish
        PlanetManager.shared.publishLocalPlanets()
    }

    private func uploadImagesAction() -> [URL]? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.jpeg, .png, .pdf, .tiff, .gif]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.message = "Please choose images to upload."
        openPanel.prompt = "Choose"
        let response = openPanel.runModal()
        return response == .OK ? openPanel.urls : nil
    }
}
