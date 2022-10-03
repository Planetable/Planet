//
//  PlanetPublishedServiceStore.swift
//  Planet
//
//  Created by Kai on 10/3/22.
//

import Foundation
import SwiftUI


class PlanetPublishedServiceStore: ObservableObject {
    static let shared = PlanetPublishedServiceStore()

    let timer = Timer.publish(every: 3, tolerance: 0.1, on: .current, in: RunLoop.Mode.default).autoconnect()

    @Published var isChoosingFolder: Bool = false
    @Published var timestamp: Int = Int(Date().timeIntervalSince1970)
    @Published private(set) var publishedFolders: [PlanetPublishedFolder] = []
    @Published private(set) var publishingFolders: [UUID] = []

    init() {
        do {
            publishedFolders = try loadPublishedFolders()
        } catch {
            debugPrint("failed to load published folders: \(error)")
        }
    }

    @MainActor
    func updatePublishedFolders(_ folders: [PlanetPublishedFolder]) {
        publishedFolders = folders.sorted(by: { a, b in
            return a.created > b.created
        })
        Task(priority: .background) {
            do {
                try savePublishedFolders()
            } catch {
                debugPrint("failed to save published folders: \(error)")
            }
        }
    }

    @MainActor
    func addPublishingFolder(_ folder: PlanetPublishedFolder) {
        guard !publishingFolders.contains(folder.id) else { return }
        publishingFolders.append(folder.id)
    }

    @MainActor
    func removePublishingFolder(_ folder: PlanetPublishedFolder) {
        guard publishingFolders.contains(folder.id) else { return }
        guard let _ = publishingFolders.removeFirst(item: folder.id) else { return }
    }
}


extension PlanetPublishedServiceStore {
    private var folderHistoryURL: URL {
        return URLUtils.publishedFolderHistoryPath.appendingPathComponent("history.json")
    }

    func loadPublishedFolders() throws -> [PlanetPublishedFolder] {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: folderHistoryURL)
        let folders: [PlanetPublishedFolder] = try decoder.decode([PlanetPublishedFolder].self, from: data)
        return folders
    }

    func savePublishedFolders() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self.publishedFolders)
        try data.write(to: folderHistoryURL)
    }
}
