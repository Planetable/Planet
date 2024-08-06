//
//  AppSettingsView.swift
//  Croptop
//

import SwiftUI


struct AppSettingsView: View {
    @StateObject private var store: PlanetStore

    init() {
        _store = StateObject(wrappedValue: PlanetStore.shared)
    }

    var body: some View {
        TabView {
            PlanetSettingsGeneralView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(PlanetSettingsTab.general)
                .frame(width: 420, height: 240)
                .environmentObject(store)

            PlanetAPIControlView()
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
