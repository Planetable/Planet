//
//  PlanetKeyManagerViewModel.swift
//  Planet
//
//  Created by Kai on 3/9/23.
//

import Foundation
import SwiftUI


class PlanetKeyManagerViewModel: ObservableObject {
    static let shared = PlanetKeyManagerViewModel()
    
    @Published var refreshing: Bool = false
    @Published var selectedKeyItemID: UUID?
    @Published private(set) var keys: [PlanetKeyItem] = []
    
    @MainActor
    func reloadPlanetKeys() async {
        refreshing = true
        defer {
            refreshing = false
        }
        var items: [PlanetKeyItem] = []
        let planets = PlanetStore.shared.myPlanets
        do {
            let allKeys = try await IPFSDaemon.shared.listKeys()
            for key in allKeys {
                for planet in planets {
                    if planet.id.uuidString == key {
                        let item = PlanetKeyItem(id: UUID(), planetID: planet.id, planetName: planet.name, keyName: planet.id.uuidString, keyID: planet.ipns, created: planet.created, modified: planet.created)
                        items.append(item)
                        break
                    }
                }
            }
        } catch {
            debugPrint("failed to prepare planet keys, error: \(error)")
        }
        self.keys = items.sorted(by: { a, b in
            return a.created > b.created
        })
    }
}
