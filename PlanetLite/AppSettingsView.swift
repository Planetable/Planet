//
//  AppSettingsView.swift
//  Croptop
//

import SwiftUI


struct AppSettingsView: View {
    var body: some View {
        TabView {
            PlanetSettingsAPIView()
                .tabItem {
                    Label("API", systemImage: "puzzlepiece.extension")
                }
                .tag(PlanetSettingsTab.api)
                .frame(width: 420, height: 240)
        }
    }
}

#Preview {
    AppSettingsView()
}
