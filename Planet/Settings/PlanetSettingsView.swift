//
//  PlanetSettingsView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI

struct PlanetSettingsView: View {
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

            PlanetSettingsPlanetsView()
                .tabItem {
                    Label("Planets", systemImage: "tray.full")
                }
                .tag(PlanetSettingsTab.planets)
                .frame(width: 420, height: 490)
                .environmentObject(store)
        }
    }
}

struct PlanetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsView()
    }
}
