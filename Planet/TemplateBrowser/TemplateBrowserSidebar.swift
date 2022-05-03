//
//  TemplateBrowserSidebar.swift
//  Planet
//
//  Created by Livid on 4/13/22.
//

import SwiftUI

struct TemplateBrowserSidebar: View {
    @EnvironmentObject var store: TemplateBrowserStore
    @Binding var selection: Template.ID?
    
    var body: some View {
        List(selection: $selection) {
            ForEach(store.templates, id: \.id) { template in
                Text(template.name)
            }
        }
        .frame(minWidth: 200)
    }
}
