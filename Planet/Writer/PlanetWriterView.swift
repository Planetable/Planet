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
    var draftPlanetID: UUID

    var isEditing: Bool = false

    @State var title: String = ""
    @State var content: String = ""
    @State var htmlContent: String = ""

    @State private var previewPath: URL!

    @State private var isToolBoxOpen: Bool = true
    @State private var isPreviewOpen: Bool = true

    @State private var selectedRanges: [NSValue] = []
    @State private var sourceFiles: Set<URL> = Set() {
        didSet {
            Task.init(priority: .utility) {
                for s in sourceFiles {
                    await uploadFile(fileURL: s)
                }
            }
        }
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

            let writerView = PlanetWriterTextView(text: $content, selectedRanges: $selectedRanges, writerID: draftPlanetID)
            let previewView = PlanetWriterPreviewView(url: previewPath)

            HSplitView {
                writerView
                    .frame(minWidth: 300,
                           maxWidth: .infinity,
                           minHeight: 300,
                           maxHeight: .infinity)
                    .onChange(of: content) { newValue in
                        htmlContent = PlanetWriterManager.shared.renderHTML(fromContent: newValue)
                        Task.init(priority: .utility) {
                            if let path = PlanetWriterManager.shared.renderPreview(content: htmlContent, forDocument: draftPlanetID) {
                                if previewPath != path {
                                    previewPath = path
                                }
                            }
                        }
                    }
                    .onChange(of: selectedRanges) { [selectedRanges] newValue in
                        debugPrint("Ranges: \(selectedRanges) -->> \(newValue)")
                    }
                if isPreviewOpen {
                    previewView
                        .frame(minWidth: 400,
                               maxWidth: .infinity,
                               minHeight: 300,
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
                                    for u in urls {
                                        sourceFiles.insert(u)
                                    }
                                }
                            }

                        ForEach(Array(sourceFiles), id: \.self) { fileURL in
                            PlanetWriterUploadImageThumbnailView(articleID: draftPlanetID, fileURL: fileURL, sourceFiles: $sourceFiles)
                        }
                    }
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.03))
            }

            Divider()

            HStack {
                Button {
                    closeAction()
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
        .frame(minWidth: 720)
        .onReceive(NotificationCenter.default.publisher(for: .closeWriterWindow, object: nil)) { n in
            guard let id = n.object as? UUID, id == draftPlanetID else { return }
            closeAction()
        }
    }

    @MainActor private func closeAction() {
        if PlanetStore.shared.writerIDs.contains(draftPlanetID) {
            PlanetStore.shared.writerIDs.remove(draftPlanetID)
        }
        if PlanetStore.shared.activeWriterID == draftPlanetID {
            PlanetStore.shared.activeWriterID = .init()
        }
        removeDraft()
    }

    @MainActor private func saveAction() {
        // make sure current new article id equals to the planet id first, then generate new article id.
        let createdArticleID = UUID()

        PlanetWriterManager.shared.setupArticlePath(articleID: createdArticleID, planetID: draftPlanetID)
        if let targetPath = PlanetWriterManager.shared.articlePath(articleID: createdArticleID, planetID: draftPlanetID) {
            copyDraft(toTargetPath: targetPath)
        }

        let article = PlanetWriterManager.shared.createArticle(withArticleID: createdArticleID, forPlanet: draftPlanetID, title: title, content: content)
        PlanetDataController.shared.save()

        if PlanetStore.shared.writerIDs.contains(draftPlanetID) {
            PlanetStore.shared.writerIDs.remove(draftPlanetID)
        }
        if PlanetStore.shared.activeWriterID == draftPlanetID {
            PlanetStore.shared.activeWriterID = .init()
        }
        PlanetStore.shared.currentArticle = article

        removeDraft()
    }

    @MainActor private func updateAction() {
        Task.init {
            try await PlanetDataController.shared.updateArticle(withID: draftPlanetID, title: title, content: content)
            if PlanetStore.shared.writerIDs.contains(draftPlanetID) {
                PlanetStore.shared.writerIDs.remove(draftPlanetID)
            }
            if PlanetStore.shared.activeWriterID == draftPlanetID {
                PlanetStore.shared.activeWriterID = .init()
            }
        }
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

    private func uploadFile(fileURL url: URL) async {
        debugPrint("uploading file: \(url) ...")
        let draftPath = PlanetWriterManager.shared.articleDraftPath(articleID: draftPlanetID)
        let fileName = url.lastPathComponent
        let targetPath = draftPath.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: url, to: targetPath)
            debugPrint("uploaded: \(targetPath)")
            if let planetID = PlanetDataController.shared.getArticle(id: draftPlanetID)?.planetID,
               let planet = PlanetDataController.shared.getPlanet(id: planetID),
               planet.isMyPlanet(),
               let planetArticlePath = PlanetWriterManager.shared.articlePath(articleID: planetID, planetID: planetID) {
                try FileManager.default.copyItem(at: targetPath, to: planetArticlePath.appendingPathComponent(fileName))
                debugPrint("uploaded to planet article path: \(planetArticlePath.appendingPathComponent(fileName))")
            }
        } catch {
            debugPrint("failed to upload file: \(url), to target path: \(targetPath), error: \(error)")
        }
    }

    private func copyDraft(toTargetPath targetPath: URL) {
        let draftPath = PlanetWriterManager.shared.articleDraftPath(articleID: draftPlanetID)
        do {
            let contentsToCopy: [URL] = try FileManager.default
            .contentsOfDirectory(at: draftPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { u in
                // MARK: TODO: ignore files that not used in article:
                 u.lastPathComponent != "preview.html"
            }
            for u in contentsToCopy {
                try? FileManager.default.copyItem(at: u, to: targetPath.appendingPathComponent(u.lastPathComponent))
            }
        } catch {
            debugPrint("failed to copy files from draft path: \(draftPath), error: \(error)")
        }
    }

    private func removeDraft() {
        let draftPath = PlanetWriterManager.shared.articleDraftPath(articleID: draftPlanetID)
        do {
            try FileManager.default.removeItem(at: draftPath)
        } catch {
            debugPrint("failed to remove draft path: \(draftPath), error: \(error)")
        }
    }
}
