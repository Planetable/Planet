//
//  TemplatePreviewView.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import SwiftUI

struct TemplatePreviewView: View {
    @StateObject var store = TemplateBrowserStore.shared
    @Binding var templateId: Template.ID?

    @State var url: URL = Bundle.main.url(forResource: "TemplatePlaceholder", withExtension: "html")!

    var body: some View {
        if templateId != nil {
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
        } else {
            Text("No Template Selected")
        }
    }

    private func preview(_ template: Template) {
        debugPrint("New Template: \(template.name)")
        if let newURL = template.renderPreview() {
            debugPrint("New Template Preview URL: \(newURL)")
            url = newURL
        }
    }
}
