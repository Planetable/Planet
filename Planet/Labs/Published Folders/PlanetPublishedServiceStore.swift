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

    static let prefixKey = "PlanetPublishedFolder-"

    let timer = Timer.publish(every: 3, tolerance: 0.1, on: .current, in: RunLoop.Mode.default).autoconnect()

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

    // MARK: -
    // https://developer.apple.com/documentation/uikit/view_controllers/providing_access_to_directories
    // https://benscheirman.com/2019/10/troubleshooting-appkit-file-permissions/
    //
    func restoreFolderAccess(forFolder folder: PlanetPublishedFolder) throws -> URL {
        let bookmarkKey = Self.prefixKey + folder.id.uuidString
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else { throw PlanetError.InternalError }
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        if isStale {
            try saveBookmarkData(forFolder: folder)
        }
        return url
    }

    func saveBookmarkData(forFolder folder: PlanetPublishedFolder) throws {
        let bookmarkData = try folder.url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        let bookmarkKey = Self.prefixKey + folder.id.uuidString
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }
    
    func removeBookmarkData(forFolder folder: PlanetPublishedFolder) {
        UserDefaults.standard.removeObject(forKey: Self.prefixKey + folder.id.uuidString)
    }
}
