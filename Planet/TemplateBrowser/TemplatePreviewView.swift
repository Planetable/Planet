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
    
    var body: some View {
        Text(template?.name ?? "No Template")
        Text(template?.description ?? "")
    }
}

extension TemplatePreviewView {
    var template: Template? {
        store[templateId]
    }
}
