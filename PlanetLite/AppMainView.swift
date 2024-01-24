//
//  AppMainView.swift
//  Croptop
//

import SwiftUI


struct AppMainView: View {
    var body: some View {
        NavigationView {
            AppSidebarView()
            AppContentView()
        }
    }
}

#Preview {
    AppMainView()
}
