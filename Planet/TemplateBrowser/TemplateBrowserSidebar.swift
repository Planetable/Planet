//
//  TemplateBrowserSidebar.swift
//  Planet
//
//  Created by Livid on 4/13/22.
//

import SwiftUI

struct TemplateBrowserSidebar: View {
    @StateObject var store = TemplateBrowserStore.shared
    @Binding var selection: Template.ID?

    var body: some View {
        List(selection: $selection) {
            ForEach(store.templates, id: \.id) { template in
                Text(template.name)
                .contextMenu {
                    Button(action: {
                        revealInFinder(template)
                    }) {
                        Text("Reveal in Finder")
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }

    private func revealInFinder(_ template: Template) {
        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
