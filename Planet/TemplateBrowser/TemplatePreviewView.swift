//
//  TemplatePreviewView.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import SwiftUI

struct TemplatePreviewView: View {
    @EnvironmentObject var store: TemplateBrowserStore
    @Binding var templateId: Template.ID?

    @State var url: URL = Bundle.main.url(forResource: "TemplatePlaceholder.html", withExtension: "")!

    var body: some View {
        if template != nil {
            // Render the template into a temporary folder and load the result
            TemplateBrowserPreviewWebView(url: $url)
                .task(priority: .utility) {
                    if let newTemplate = store[templateId] {
                        debugPrint("New Template: \(newTemplate.name)")
                        if let newURL = render(newTemplate) {
                            debugPrint("New Template Preview URL: \(newURL)")
                            url = newURL
                        }
                    }
                }
                .onChange(of: templateId) { newTemplateId in
                    if let newTemplate = store[newTemplateId] {
                        debugPrint("New Template: \(newTemplate.name)")
                        if let newURL = render(newTemplate) {
                            debugPrint("New Template Preview URL: \(newURL)")
                            url = newURL
                        }
                    }
                }

        } else {
            Text("No Template Selected")
        }
    }
}

extension TemplatePreviewView {
    var template: Template? {
        store[templateId]
    }

    func render(_ template: Template) -> URL? {
        let title: String = "Template Preview \(template.name)"
        let content: String = "Hello World \(template.name)"

        let templateFolder: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(template.name)
        let assetsFolderPath: URL = templateFolder.appendingPathComponent("assets")
        if !FileManager.default.fileExists(atPath: assetsFolderPath.path) {
            try? FileManager.default.createDirectory(at: assetsFolderPath, withIntermediateDirectories: true, attributes: nil)
        }

        let articleFolderPath: URL = templateFolder.appendingPathComponent("preview")
        if !FileManager.default.fileExists(atPath: articleFolderPath.path) {
            try? FileManager.default.createDirectory(at: articleFolderPath, withIntermediateDirectories: true, attributes: nil)
        }

        let articlePath: URL = articleFolderPath.appendingPathComponent("blog.html")
        let output: String = content
        do {
            try output.data(using: .utf8)?.write(to: articlePath)
            debugPrint("Preview article path: \(articlePath)")
            return articlePath
        } catch {
            debugPrint("Failed to render preview: \(error)")
            return nil
        }
    }
}
