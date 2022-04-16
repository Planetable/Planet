//
//  TemplateBrowserView.swift
//  Planet
//
//  Created by Xin Liu on 4/13/22.
//

import SwiftUI

struct TemplateBrowserView: View {
    var body: some View {
        NavigationView {
            TemplateBrowserSidebar()
            Text("Hello World")
        }
    }
}

struct TemplateBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateBrowserView()
    }
}
