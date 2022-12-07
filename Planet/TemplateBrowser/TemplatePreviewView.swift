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
                            preview(template, withPreviewIndex: UserDefaults.standard.integer(forKey: String.selectedPreviewIndex))
                        }
                    }
                    .onChange(of: templateId) { newTemplateId in
                        if let newTemplate = store[newTemplateId] {
                            preview(newTemplate, withPreviewIndex: UserDefaults.standard.integer(forKey: String.selectedPreviewIndex))
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .refreshTemplatePreview, object: nil)) { _ in
                        if let template = store[templateId] {
                            preview(template)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .templatePreviewIndexUpdated)) { n in
                        guard let template = store[templateId], let index = n.object as? NSNumber else { return }
                        preview(template, withPreviewIndex: index.intValue)
                    }
            } else {
                Text("No Template Selected")
            }
        }
        .edgesIgnoringSafeArea(.vertical)
        .frame(minWidth: .templateContentWidth, maxWidth: .infinity, minHeight: .templateContentHeight, maxHeight: .infinity, alignment: .center)
    }

    private func preview(_ template: Template, withPreviewIndex index: Int = 0) {
        debugPrint("New Template: \(template.name)")
        if let newURL = template.renderPreview(withPreviewIndex: index) {
            debugPrint("New Template Preview URL: \(newURL)")
            // trigger refresh even when URL is the same
            url = newURL.appendingQueryParameters(
                ["t": "\(Date().timeIntervalSince1970)"]
            )

            NotificationCenter.default.post(name: .loadTemplatePreview, object: nil)
        }
    }
}
