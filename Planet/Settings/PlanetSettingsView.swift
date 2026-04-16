//
//  PlanetSettingsView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI

struct PlanetSettingsView: View {
    @StateObject private var store: PlanetStore
    @StateObject private var serviceStore: PlanetPublishedServiceStore
    let SETTINGS_WINDOW_WIDTH: CGFloat = 600

    init() {
        _store = StateObject(wrappedValue: PlanetStore.shared)
        _serviceStore = StateObject(wrappedValue: PlanetPublishedServiceStore.shared)
    }

    var body: some View {
        TabView {
            PlanetSettingsGeneralView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(PlanetSettingsTab.general)
                .frame(width: SETTINGS_WINDOW_WIDTH, height: .infinity)
                .environmentObject(store)

            PlanetSettingsAIView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(PlanetSettingsTab.ai)
                .frame(width: SETTINGS_WINDOW_WIDTH, height: 420)

            PlanetSettingsPlanetsView()
                .tabItem {
                    Label("Planets", systemImage: "tray.full")
                }
                .tag(PlanetSettingsTab.planets)
                .frame(width: SETTINGS_WINDOW_WIDTH, height: 490)
                .environmentObject(store)

            PlanetAPIControlView()
                .tabItem {
                    Label("API", systemImage: "puzzlepiece.extension")
                }
                .tag(PlanetSettingsTab.api)
                .frame(width: SETTINGS_WINDOW_WIDTH, height: 240)

            PlanetSettingsPublishedFoldersView()
                .tabItem {
                    Label("Published Folders", systemImage: "server.rack")
                }
                .tag(PlanetSettingsTab.publishedFolders)
                .frame(width: SETTINGS_WINDOW_WIDTH, height: 180)
                .environmentObject(serviceStore)
        }
    }
}

struct PlanetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsView()
    }
}
