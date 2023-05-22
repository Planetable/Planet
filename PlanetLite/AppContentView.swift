//
//  AppContentView.swift
//  PlanetLite
//

import SwiftUI


struct AppContentView: View {
    @StateObject private var planetStore: PlanetStore
    
    init() {
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
    }

    var body: some View {
        VStack {
            if planetStore.myPlanets.count == 0 {
                Text("No planet yet ...")
                    .foregroundColor(.secondary)
                Button {
                    planetStore.isCreatingPlanet = true
                } label: {
                    Text("Create New Planet")
                }
                .disabled(planetStore.isCreatingPlanet)
            } else {
                switch planetStore.selectedView {
                case .myPlanet(let planet):
                    planetContentGridView(planet)
                default:
                    Text("No content ...")
                }
            }
        }
        .padding(0)
        .edgesIgnoringSafeArea(.top)
        .frame(minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, maxWidth: .infinity, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    private func planetContentGridView(_ planet: MyPlanetModel) -> some View {
        Text("Content for planet: \(planet.name)")
    }
}

struct AppContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppContentView()
    }
}
