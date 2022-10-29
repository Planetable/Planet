//
//  PlanetSettingsViewModel.swift
//  Planet
//
//  Created by Kai on 9/11/22.
//

import Foundation


class PlanetSettingsViewModel: ObservableObject {
    static let shared: PlanetSettingsViewModel = PlanetSettingsViewModel()
    
    @Published var myArchivedPlanets: [MyPlanetModel] = []
    
    init() {
        do {
            try loadArchivedPlanets()
        } catch {
            fatalError("Error when accessing planet repo: \(error)")
        }
    }
    
    func loadArchivedPlanets() throws {
        let myPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: MyPlanetModel.myPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        myArchivedPlanets = myPlanetDirectories.compactMap { try? MyPlanetModel.load(from: $0) }
        myArchivedPlanets = myArchivedPlanets.filter { $0.archived == true }
    }
}
