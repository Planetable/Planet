//
//  TemplateBrowserView.swift
//  Planet
//
//  Created by Xin Liu on 4/13/22.
//

import SwiftUI

struct TemplateBrowserView: View {
    @EnvironmentObject var templateStore: TemplateBrowserStore
    @AppStorage("TemplateBrowserView.selectedTemplateID") private var selectedTemplateID: Template.ID?

    var template: Template? {
        templateStore[selectedTemplateID]
    }

    var body: some View {
        NavigationView {
            TemplateBrowserSidebar(selection: $selectedTemplateID)
            TemplatePreviewView(templateId: $selectedTemplateID)
                .navigationTitle(template?.name ?? "Template Browser")
                .navigationSubtitle(navigationSubtitle())
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Spacer()

                        Button {
                            refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        }
    }

    private func refresh() {
        NotificationCenter.default.post(name: .refreshTemplatePreview, object: nil)
    }

    private func navigationSubtitle() -> String {
        if let template = template {
            return "\(template.author) · Version \(template.version)"
        } else {
            return ""
        }
    }
}

struct TemplateBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateBrowserView()
    }
}
