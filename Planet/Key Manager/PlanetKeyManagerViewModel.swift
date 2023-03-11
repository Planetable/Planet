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
    @Published private(set) var keysInKeystore: [String] = []
    
    @MainActor
    func updateKeyItem(_ item: PlanetKeyItem) {
        keys = keys.map() { it in
            if it.id == item.id {
                return item
            }
            return it
        }.sorted(by: { a, b in
            return a.created > b.created
        })
    }
    
    @MainActor
    func reloadPlanetKeys() async {
        selectedKeyItemID = nil
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
        do {
            let (ret, out, _) = try IPFSCommand.listKeys().run()
            if ret == 0 {
                if let output = String(data: out, encoding: .utf8)?.trimmingCharacters(in: .whitespaces) {
                    keysInKeystore = output.components(separatedBy: .newlines).filter({ $0 != "" && $0 != "self" })
                }
            }
        } catch {
            debugPrint("failed to list keys: \(error)")
        }
    }
}
