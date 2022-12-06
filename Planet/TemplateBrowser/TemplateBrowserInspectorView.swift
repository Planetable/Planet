//
//  TemplateBrowserInspectorView.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import SwiftUI

struct TemplateBrowserInspectorView: View {
    var body: some View {
        VStack {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
        .frame(minWidth: .templateInspectorWidth, maxWidth: .templateInspectorMaxWidth)
    }
}

struct TemplateBrowserInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateBrowserInspectorView()
    }
}
