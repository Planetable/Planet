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
    @Published var followingArchivedPlanets: [FollowingPlanetModel] = []

    init() {
        do {
            Task(priority: .high) {
                try await loadArchivedPlanets()
            }
        } catch {
            fatalError("Error when accessing planet repo: \(error)")
        }
    }

    func loadArchivedPlanets() async throws {
        // TODO: Use PlanetStore.shared.myPlanets and PlanetStore.shared.followingPlanets instead of accessing the repo directly
        let myPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: MyPlanetModel.myPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        let archivedMyPlanets = myPlanetDirectories.compactMap { try? MyPlanetModel.load(from: $0) }
        Task { @MainActor in
            myArchivedPlanets = archivedMyPlanets.filter { $0.archived == true }
        }

        let followingPlanetDirectories = try FileManager.default.contentsOfDirectory(
            at: FollowingPlanetModel.followingPlanetsPath,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        let archivedFollowingPlanets = followingPlanetDirectories.compactMap { try? FollowingPlanetModel.load(from: $0) }
        Task { @MainActor in
            followingArchivedPlanets = archivedFollowingPlanets.filter { $0.archived == true }
        }
    }
}
