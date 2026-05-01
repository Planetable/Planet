//
//  PlanetSettingsPlanetsView.swift
//  Planet
//
//  Created by Xin Liu on 10/28/22.
//

import SwiftUI

struct PlanetSettingsPlanetsView: View {
    @EnvironmentObject private var store: PlanetStore
    @State private var unarchiveErrorMessage: String?

    var body: some View {
        VStack {
            Text(
                "Here are your archived Planets. Archived planets are not auto published or updated. You can unarchive them from here."
            ).padding(0)

            Table(store.myArchivedPlanets) {
                TableColumn("Archived My Planet") { planet in
                    HStack {
                        planet.avatarView(size: 24)
                        Text(planet.name)
                        Spacer()
                        Button("Unarchive") {
                            unarchive(planet)
                        }
                    }.padding(4)
                }
            }.tableStyle(.bordered)

            Table(store.followingArchivedPlanets) {
                TableColumn("Archived Following Planet") { planet in
                    HStack {
                        planet.avatarView(size: 24)
                        Text(planet.name)
                        Spacer()
                        Button("Unarchive") {
                            unarchive(planet)
                        }
                    }.padding(4)
                }
            }.tableStyle(.bordered)
        }.padding()
        .alert(
            isPresented: Binding(
                get: { unarchiveErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        unarchiveErrorMessage = nil
                    }
                }
            )
        ) {
            Alert(
                title: Text(L10n("Failed to Unarchive Planet")),
                message: Text(unarchiveErrorMessage ?? ""),
                dismissButton: .default(Text(L10n("OK")))
            )
        }
    }

    private func unarchive(_ planet: MyPlanetModel) {
        let oldArchived = planet.archived
        let oldArchivedAt = planet.archivedAt
        planet.archived = false
        planet.archivedAt = nil
        do {
            try planet.save()
            store.myArchivedPlanets.removeAll { $0.id == planet.id }
            store.myPlanets.insert(planet, at: 0)
        }
        catch {
            planet.archived = oldArchived
            planet.archivedAt = oldArchivedAt
            unarchiveErrorMessage = error.localizedDescription
        }
    }

    private func unarchive(_ planet: FollowingPlanetModel) {
        let oldArchived = planet.archived
        let oldArchivedAt = planet.archivedAt
        planet.archived = false
        planet.archivedAt = nil
        do {
            try planet.save()
            store.followingArchivedPlanets.removeAll { $0.id == planet.id }
            store.followingPlanets.insert(planet, at: 0)
        }
        catch {
            planet.archived = oldArchived
            planet.archivedAt = oldArchivedAt
            unarchiveErrorMessage = error.localizedDescription
        }
    }
}

struct PlanetSettingsPlanetsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsPlanetsView()
    }
}
