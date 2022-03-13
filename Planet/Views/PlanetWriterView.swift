//
//  PlanetWriterView.swift
//  Planet
//
//  Created by Kai on 2/22/22.
//

import SwiftUI
import CodeEditor


struct PlanetWriterView: View {
    var articleID: UUID

    var isEditing: Bool = false

    @State var title: String = ""
    @State var content: String = ""

    @State private var isFilePanelOpen: Bool = false
    @State private var isToolBoxOpen: Bool = false
    @State private var isPreviewOpen: Bool = false

    static private let initialSource = ""
    @State private var source = Self.initialSource
    @State private var selection = Self.initialSource.endIndex..<Self.initialSource.endIndex
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
        GeometryReader { g in
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

                    HStack (spacing: 16) {
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
                    CodeEditor(source: $source,
                               selection: $selection,
                               language: .markdown,
                               theme: .atelierSavannaDark,
                               flags: [.selectable, .editable, .smartIndent],
                               indentStyle: .softTab(width: 4),
                               autoPairs: ["{": "}", "[": "]", "<": ">", "'": "'", "\"": "\""],
                               autoscroll: true)
                        .onChange(of: source) { [source] newValue in
                            Task.init(priority: .userInitiated) {
                                await processInput(fromSource: source, withUpdatedSource: newValue)
                            }
                        }
                        .onChange(of: selection) { [selection] newValue in
                            debugPrint("selection index changed from: \(selection.lowerBound.utf16Offset(in: source)) -> \(newValue.lowerBound.utf16Offset(in: source))")
                        }

                    if isPreviewOpen {
                        VStack {
                            Text("Preview Here.")
                        }
                        .frame(minWidth: g.size.width / 2.0, idealWidth: g.size.width, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                if isToolBoxOpen {

                    Divider()

                    HStack {
                        ScrollView(.horizontal) {
                            HStack (spacing: 8) {
                                ForEach(Array(sourceFiles), id: \.self) { fileURL in
                                    Text("Text")
                                }
                            }
                        }
                        .padding(4)
                    }
                    .frame(height: 48)
                    .background(Color.secondary.opacity(0.15))

                    Divider()

                    HStack {
                        Button {
                            debugPrint("current position: \(selection)")
                            isFilePanelOpen.toggle()
                        } label: {
                            Image(systemName: "plus.app")
                        }

                        Button("Insert Sample Image") {
                            let sample = "/Users/kai/Desktop/P3PC-6641-01EN.pdf"
                            var sampleCharacters = [Character]()
                            for char in sample {
                                sampleCharacters.append(char)
                            }
                            source.insert(contentsOf: sampleCharacters, at: selection.lowerBound)
                        }

                        Spacer()

                        Button("Cursor Front") {
                            selection = source.startIndex..<source.startIndex
                        }

                        Button("Cursor End") {
                            selection = source.endIndex..<source.endIndex
                        }

                        Button("Clear All") {
                            source = ""
                            selection = source.endIndex..<source.endIndex
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 36)
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
        }
        .padding(0)
        .frame(minWidth: 480, idealWidth: 480, maxWidth: .infinity, minHeight: 320, idealHeight: 320, maxHeight: .infinity, alignment: .center)
        .onReceive(NotificationCenter.default.publisher(for: .closeWriterWindow, object: nil)) { n in
            guard let id = n.object as? UUID else { return }
            guard id == self.articleID else { return }
            self.closeAction()
        }
        .fileImporter(isPresented: $isFilePanelOpen, allowedContentTypes: [.image, .movie, .url, .pdf], allowsMultipleSelection: true) { result in
            if let urls = try? result.get() {
                for u in urls {
                    sourceFiles.insert(u)
                }
            }
        }
    }

    private func closeAction() {
        DispatchQueue.main.async {
            if PlanetStore.shared.writerIDs.contains(articleID) {
                PlanetStore.shared.writerIDs.remove(articleID)
            }
            if PlanetStore.shared.activeWriterID == articleID {
                PlanetStore.shared.activeWriterID = .init()
            }
        }
        removeDraft()
    }

    private func saveAction() {
        debugPrint("About to save ")
        // make sure current new article id equals to the planet id first, then generate new article id.
        let planetID = articleID
        let createdArticleID = UUID()
        Task.init(priority: .utility) {
            await PlanetDataController.shared.createArticle(withID: createdArticleID, forPlanet: planetID, title: title, content: content, link: "/\(createdArticleID)/")
        }
        DispatchQueue.main.async {
            if PlanetStore.shared.writerIDs.contains(articleID) {
                PlanetStore.shared.writerIDs.remove(articleID)
            }
            if PlanetStore.shared.activeWriterID == articleID {
                PlanetStore.shared.activeWriterID = .init()
            }
        }
        removeDraft()
    }

    private func updateAction() {
        debugPrint("About to update")
        PlanetDataController.shared.updateArticle(withID: articleID, title: title, content: content)
        DispatchQueue.main.async {
            if PlanetStore.shared.writerIDs.contains(articleID) {
                PlanetStore.shared.writerIDs.remove(articleID)
            }
            if PlanetStore.shared.activeWriterID == articleID {
                PlanetStore.shared.activeWriterID = .init()
            }
        }
    }

    private func processInput(fromSource theSource: String, withUpdatedSource updatedSource: String) async {
        let originalSource: String = theSource
        var processedSource = updatedSource
        debugPrint("processing input source: \(theSource) -> updated source: \(updatedSource)")

        let difference = updatedSource.difference(from: theSource)
        let removals = difference.removals
        let insertions = difference.insertions
        let counts = difference.count

        guard counts > 0 else {
            debugPrint("skiped.")
            return
        }
        debugPrint("REMOVALS: \(removals), INSERTIONS: \(insertions), DELTA COUNTS: \(counts)")

        guard processedSource.count != originalSource.count else {
            debugPrint("skiped.")
            return
        }
        guard processedSource != originalSource else {
            debugPrint("skiped.")
            return
        }

        self.source = processedSource
        debugPrint("updated.")
    }

    private func uploadFile(fileURL url: URL) async {
        debugPrint("uploading file: \(url) ...")
        let draftPath = PlanetManager.shared.articleDraftPath(articleID: articleID)
        let fileName = url.lastPathComponent
        let targetPath = draftPath.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: url, to: targetPath)
            debugPrint("uploaded: \(targetPath)")
            if let planetID = PlanetDataController.shared.getArticle(id: articleID)?.planetID {
                if let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet() {
                    
                }
            }
        } catch {
            debugPrint("failed to upload file: \(url), to target path: \(targetPath), error: \(error)")
        }
    }

    private func removeDraft() {
        let draftPath = PlanetManager.shared.articleDraftPath(articleID: articleID)
        do {
            try FileManager.default.removeItem(at: draftPath)
        } catch {
            debugPrint("failed to remove draft path: \(draftPath), error: \(error)")
        }
    }
}

struct PlanetWriterView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetWriterView(articleID: .init())
    }
}
