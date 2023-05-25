//
//  AppContentView.swift
//  PlanetLite
//

import SwiftUI


struct AppContentView: View {
    @StateObject private var planetStore: PlanetStore
    
    static let itemWidth: CGFloat = 128
    
    let dropDelegate: AppContentDropDelegate
    
    init() {
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
        dropDelegate = AppContentDropDelegate()
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
                        .foregroundColor(.secondary)
                }
            }
        }
        .onDrop(of: [.image], delegate: dropDelegate)
        .padding(0)
        .frame(minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, idealWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN, maxWidth: .infinity, minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN, maxHeight: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    private func planetContentGridView(_ planet: MyPlanetModel) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.itemWidth, maximum: Self.itemWidth), spacing: 16)], spacing: 16) {
                ForEach(planet.articles, id: \.id) { article in
                    AppContentItemView(article: article, width: Self.itemWidth)
                        .environmentObject(planetStore)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct AppContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppContentView()
    }
}
