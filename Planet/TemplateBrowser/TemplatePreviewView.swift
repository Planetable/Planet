//
//  TemplatePreviewView.swift
//  Planet
//
//  Created by Xin Liu on 5/3/22.
//

import SwiftUI

struct TemplatePreviewView: View {
    @StateObject private var store: TemplateStore
    @State private var url: URL = Bundle.main.url(forResource: "TemplatePlaceholder", withExtension: "html")!
    
    init() {
        _store = StateObject(wrappedValue: TemplateStore.shared)
    }

    var body: some View {
        VStack {
            if let templateId = store.selectedTemplateID {
                // Render the template into a temporary folder and load the result
                TemplateBrowserPreviewWebView(url: $url)
                    .task(priority: .utility) {
                        if let template = store[templateId] {
                            preview(template)
                        }
                    }
                    .onChange(of: templateId) { newTemplateId in
                        if let newTemplate = store[newTemplateId] {
                            preview(newTemplate)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .refreshTemplatePreview, object: nil)) { _ in
                        if let template = store[templateId] {
                            preview(template)
                        }
                    }
            } else {
                Text("No Template Selected")
            }
        }
        .edgesIgnoringSafeArea(.vertical)
        .frame(minWidth: .templateContentWidth, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .center)
    }

    private func preview(_ template: Template) {
        debugPrint("New Template: \(template.name)")
        if let newURL = template.renderPreview() {
            debugPrint("New Template Preview URL: \(newURL)")
            // trigger refresh even when URL is the same
            url = newURL.appendingQueryParameters(
                ["t": "\(Date().timeIntervalSince1970)"]
            )

            NotificationCenter.default.post(name: .loadTemplatePreview, object: nil)
        }
    }
}
