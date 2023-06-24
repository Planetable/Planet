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
                // Default empty view of the Lite app
                Text("Hello World :)")
                    .foregroundColor(.secondary)
                Button {
                    planetStore.isCreatingPlanet = true
                } label: {
                    Text("Create First Planet")
                }
                .disabled(planetStore.isCreatingPlanet)
                Text("Learn more about [Planet](https://planetable.xyz) and [Croptop](https://croptop.eth.limo)")
                    .foregroundColor(.secondary)
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
        .background(Color(NSColor.textBackgroundColor))
    }

    @ViewBuilder
    private func planetContentGridView(_ planet: MyPlanetModel) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.itemWidth, maximum: Self.itemWidth), spacing: 16)], alignment: .leading, spacing: 0) {
                ForEach(planet.articles, id: \.id) { article in
                    AppContentItemView(article: article, width: Self.itemWidth)
                        .environmentObject(planetStore)
                }
            }
        }
    }
}

struct AppContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppContentView()
    }
}
