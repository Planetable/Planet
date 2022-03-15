//
//  PlanetWriterView.swift
//  Planet
//
//  Created by Kai on 2/22/22.
//

import SwiftUI
import CodeEditor
import Stencil
import PathKit
import WebKit
import Ink


struct PlanetWriterView: View {
    var articleID: UUID

    var isEditing: Bool = false

    @State var title: String = ""
    @State var content: String = ""

    @State private var isFilePanelOpen: Bool = false
    @State private var isToolBoxOpen: Bool = true
    @State private var isPreviewOpen: Bool = false

    static private let initialSource = ""
    @State private var source = Self.initialSource {
        didSet {
            content = source
        }
    }
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
            
            if isPreviewOpen {
                PlanetWriterPreviewView(articleID: articleID, content: content)
            } else {
                CodeEditor(source: $source,
                           selection: $selection,
                           language: .markdown,
                           theme: .atelierSavannaDark,
                           flags: [.selectable, .editable, .smartIndent],
                           indentStyle: .softTab(width: 4),
                           autoPairs: ["{": "}", "[": "]", "<": ">", "'": "'", "\"": "\""],
                           autoscroll: true)
                    .onChange(of: source) { [source] newValue in
                        Task.init(priority: .background) {
                            await processInput(fromSource: source, withUpdatedSource: newValue)
                        }
                    }
                    .onChange(of: selection) { [selection] newValue in
                        debugPrint("selection index changed from: \(selection.lowerBound.utf16Offset(in: source)) -> \(newValue.lowerBound.utf16Offset(in: source))")
                    }
            }

            if isToolBoxOpen && isPreviewOpen == false {

                Divider()

                ScrollView(.horizontal) {
                    HStack (spacing: 0) {
                        Image(systemName: "plus.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40, alignment: .center)
                            .padding(.leading, 16)
                            .opacity(0.5)
                            .onTapGesture {
                                isFilePanelOpen = true
                            }

                        ForEach(Array(sourceFiles), id: \.self) { fileURL in
                            thumbnailFromFile(fileURL: fileURL)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40, alignment: .center)
                                .padding(.leading, 16)
                                .onTapGesture {
                                    insertFile(fileURL: fileURL)
                                }
                        }
                    }
                }
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.15))
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
        
        PlanetManager.shared.setupArticlePath(articleID: createdArticleID, planetID: planetID)
        if let targetPath = PlanetManager.shared.articlePath(articleID: createdArticleID, planetID: planetID) {
            copyDraft(toTargetPath: targetPath)
        }

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

    private func moveCursorBeginningAction() {
        selection = source.startIndex..<source.startIndex
    }

    private func moveCursorToEndAction() {
        selection = source.endIndex..<source.endIndex
    }

    private func cleanUpAction() {
        source = ""
        selection = source.endIndex..<source.endIndex
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
                    if let planetArticlePath = PlanetManager.shared.articlePath(articleID: articleID, planetID: planetID) {
                        try FileManager.default.copyItem(at: targetPath, to: planetArticlePath.appendingPathComponent(fileName))
                        debugPrint("uploaded to planet article path: \(planetArticlePath.appendingPathComponent(fileName))")
                    }
                }
            }
        } catch {
            debugPrint("failed to upload file: \(url), to target path: \(targetPath), error: \(error)")
        }
    }

    private func thumbnailFromFile(fileURL url: URL) -> Image {
        // check file locations
        let size = NSSize(width: 80, height: 80)
        let filename = url.lastPathComponent

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

    private func insertFile(fileURL url: URL) {
        debugPrint("inserting file: \(url) ...")
        func _getCharacters(fromContent content: String) -> [Character] {
            var cc = [Character]()
            for c in content {
                cc.append(c)
            }
            return cc
        }

        let filename = url.lastPathComponent
        let fileExtension = url.pathExtension
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

        guard let filePath = filePath else {
            return
        }

        let content: String = (isImage ? "!" : "") + "[\(filename)]" + "(" + filename + ")"
        source.insert(contentsOf: _getCharacters(fromContent: content), at: selection.lowerBound)
    }
    
    private func copyDraft(toTargetPath targetPath: URL) {
        let draftPath = PlanetManager.shared.articleDraftPath(articleID: articleID)
        do {
            let contentsToCopy: [URL] = try FileManager.default.contentsOfDirectory(at: draftPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter({ u in
                return u.lastPathComponent != "basic_preview.html"
            })
            for u in contentsToCopy {
                do {
                    try FileManager.default.copyItem(at: u, to: targetPath.appendingPathComponent(u.lastPathComponent))
                } catch {
                    
                }
            }
        } catch {
            debugPrint("failed to copy files from draft path: \(draftPath), error: \(error)")
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


private struct PlanetWriterPreviewView: View {
    var articleID: UUID
    var content: String

    @State private var rendered: String = ""

    var body: some View {
        VStack {
            SimpleWriterWebView(content: $rendered)
                .task {
                    rendered = renderPreview(articleContent: content)
                }
        }
        .padding(0)
    }

    private func renderPreview(articleContent: String) -> String {
        guard articleContent != "" else { return "" }
        
        let manager = SimpleWriterManager.shared
        if manager.articleID == nil {
            manager.setup(withArticleID: articleID)
        }
        
        let result = manager.parser.parse(articleContent)
        let content_html = result.html
        let context: [String: Any] = ["content_html": content_html]
        do {
            let output: String = try manager.env.renderTemplate(name: manager.templateName, context: context)
            debugPrint("rendered content: \(output)")
            return output
        } catch {
            return articleContent
        }
    }
}


private struct SimpleWriterWebView: NSViewRepresentable {

    public typealias NSViewType = WKWebView

    @Binding var content: String
    let navigationHelper = WebViewHelper()

    func makeNSView(context: NSViewRepresentableContext<SimpleWriterWebView>) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = navigationHelper
        webview.loadHTMLString(content, baseURL: nil)
        return webview
    }

    func updateNSView(_ webview: WKWebView, context: NSViewRepresentableContext<SimpleWriterWebView>) {
        webview.loadHTMLString(content, baseURL: nil)
    }
}


private class SimpleWriterWebViewHelper: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}


private class SimpleWriterManager: NSObject {
    static let shared: SimpleWriterManager = SimpleWriterManager()
    
    var articleID: UUID!
    var loader: FileSystemLoader!
    var env: Stencil.Environment!
    var parser: MarkdownParser!
    var templateName: String!

    override init() {
    }
    
    func setup(withArticleID id: UUID) {
        debugPrint("Setup Simple Writer Manager for article: \(id)")
        articleID = id
        
        let previewTemplatePath = Bundle.main.url(forResource: "BasicPreview", withExtension: "html")!
        let templatePath = PlanetManager.shared.articleDraftPath(articleID: articleID).appendingPathComponent("basic_preview.html")
        if !FileManager.default.fileExists(atPath: templatePath.path) {
            do {
                try FileManager.default.copyItem(at: previewTemplatePath, to: templatePath)
            } catch {
            }
        }
        
        loader = FileSystemLoader(paths: [Path(templatePath.deletingLastPathComponent().path)])
        env = Environment(loader: loader)
        parser = MarkdownParser()
        templateName = templatePath.lastPathComponent
    }
}
