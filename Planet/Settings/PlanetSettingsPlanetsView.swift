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
                TableColumn("Planet") { planet in
                    HStack {
                        planet.avatarView(size: 24)
                        Text(String(planet.name))
                        Spacer()
                        Button("Unarchive") {
                            planet.archived = false
                            planet.archivedAt = nil
                            do {
                                try planet.save()
                                try viewModel.loadArchivedPlanets()
                                PlanetStore.shared.myPlanets.insert(planet, at: 0)
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
