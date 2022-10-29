//
//  PlanetSettingsPlanetsView.swift
//  Planet
//
//  Created by Xin Liu on 10/28/22.
//

import SwiftUI

struct PlanetSettingsPlanetsView: View {
    @EnvironmentObject private var viewModel: PlanetSettingsViewModel

    var body: some View {
        VStack {
            Text(
                "Here are your archived Planets. Archived planets are not auto published or updated. You can unarchive them from here."
            ).padding(0)

            Table(viewModel.myArchivedPlanets) {
                TableColumn("Archived My Planet") { planet in
                    HStack {
                        planet.avatarView(size: 24)
                        Text(String(planet.name))
                        Spacer()
                        Button("Unarchive") {
                            planet.archived = false
                            planet.archivedAt = nil
                            do {
                                try planet.save()
                                viewModel.myArchivedPlanets.removeAll { $0.id == planet.id }
                                PlanetStore.shared.myPlanets.insert(planet, at: 0)
                            }
                            catch {
                                fatalError("Error when accessing planet repo: \(error)")
                            }
                        }
                    }.padding(4)
                }
            }

            Table(viewModel.followingArchivedPlanets) {
                TableColumn("Archived Following Planet") { planet in
                    HStack {
                        planet.avatarView(size: 24)
                        Text(String(planet.name))
                        Spacer()
                        Button("Unarchive") {
                            planet.archived = false
                            planet.archivedAt = nil
                            do {
                                try planet.save()
                                viewModel.followingArchivedPlanets.removeAll { $0.id == planet.id }
                                PlanetStore.shared.followingPlanets.insert(planet, at: 0)
                            }
                            catch {
                                fatalError("Error when accessing planet repo: \(error)")
                            }
                        }
                    }.padding(4)
                }
            }
        }.padding()
    }
}

struct PlanetSettingsPlanetsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsPlanetsView()
    }
}
