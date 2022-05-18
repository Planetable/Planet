//
//  TemplateBrowserView.swift
//  Planet
//
//  Created by Xin Liu on 4/13/22.
//

import SwiftUI

struct TemplateBrowserView: View {
    @StateObject var store = TemplateBrowserStore.shared
    @AppStorage("TemplateBrowserView.selectedTemplateID") private var selectedTemplateID: Template.ID?

    var template: Template? {
        store[selectedTemplateID]
    }

    var body: some View {
        NavigationView {
            TemplateBrowserSidebar(selection: $selectedTemplateID)
            TemplatePreviewView(templateId: $selectedTemplateID)
                .navigationTitle(template?.name ?? "Template Browser")
        }
    }
}

struct TemplateBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateBrowserView()
    }
}
