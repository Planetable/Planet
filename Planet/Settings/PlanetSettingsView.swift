//
//  PlanetSettingsView.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import SwiftUI


struct PlanetSettingsView: View {
    @StateObject private var viewModel: PlanetSettingsViewModel

    init() {
        _viewModel = StateObject(wrappedValue: PlanetSettingsViewModel.shared)
    }

    var body: some View {
        TabView {
            PlanetSettingsGeneralView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(PlanetSettingsTab.general)
                .frame(width: 420, height: 240)
                .environmentObject(viewModel)
        }
    }
}


struct PlanetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsView()
    }
}
