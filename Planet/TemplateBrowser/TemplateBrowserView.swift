//
//  TemplateBrowserView.swift
//  Planet
//
//  Created by Xin Liu on 4/13/22.
//

import SwiftUI

struct TemplateBrowserView: View {
    @EnvironmentObject var store: TemplateBrowserStore
    @AppStorage("TemplateBrowserView.selectedTemplateID") private var selectedTemplateID: Template.ID?
    
    var body: some View {
        NavigationView {
            TemplateBrowserSidebar(selection: $selectedTemplateID)
            TemplatePreviewView(templateId: $selectedTemplateID)
        }
    }
}

struct TemplateBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateBrowserView()
    }
}
