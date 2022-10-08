//
//  PlanetMainView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetMainView: View {
    @EnvironmentObject var planetStore: PlanetStore

    @State private var isInfoAlert: Bool = false
    @State private var isFollowingAlert: Bool = false

    var body: some View {
        NavigationView {
            PlanetSidebarView()

            ArticleListView()

            ArticleView()
        }
        .alert(isPresented: $planetStore.isShowingAlert) {
            Alert(
                title: Text(PlanetStore.shared.alertTitle),
                message: Text(PlanetStore.shared.alertMessage),
                dismissButton: Alert.Button.cancel(Text("OK")) {
                    PlanetStore.shared.alertTitle = ""
                    PlanetStore.shared.alertMessage = ""
                }
            )
        }
        .fileImporter(
            isPresented: $planetStore.isImportingPlanet,
            allowedContentTypes: [.data, .package]
        ) { result in
            if let url = try? result.get(),
               url.pathExtension == "planet" {
                do {
                    let planet = try MyPlanetModel.importBackup(from: url)
                    PlanetStore.shared.myPlanets.insert(planet, at: 0)
                } catch {
                    PlanetStore.shared.alert(title: "Failed to import planet")
                }
            }
        }
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetInfoView(planet: planet)
            } else
            if case .followingPlanet(let planet) = planetStore.selectedView {
                FollowingPlanetInfoView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanet) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetEditView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanetCustomCode) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetCustomCodeView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanetPodcastSettings) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetPodcastSettingsView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isMigrating) {
            MigrationProgressView()
        }
    }
}

struct PlanetMainView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMainView()
    }
}
