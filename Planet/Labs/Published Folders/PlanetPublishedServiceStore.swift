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
        let updatedFolders = publishedFolders
        Task(priority: .background) {
            for folder in updatedFolders {
                do {
                    try saveBookmarkData(workDir: folder.url, forFolder: folder)
                } catch {
                    debugPrint("failed to save work directory \(folder) as bookmark: \(error)")
                }
            }
        }
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
        let defaults = UserDefaults.standard
        for folder in folders {
            let key = Self.prefixKey + folder.id.uuidString
            guard let bookmarkData = defaults.object(forKey: key) as? Data else { continue }
            let url = try restoreFileAccess(with: bookmarkData, forFolder: folder)
            if !url.startAccessingSecurityScopedResource() {
                print("startAccessingSecurityScopedResource returned false. This directory might not need it, or this URL might not be a security scoped URL, or maybe something's wrong?")
            }
            let paths = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                        .map {
                            $0.relativePath.replacingOccurrences(of: url.path, with: "")
                        }
            url.stopAccessingSecurityScopedResource()
            debugPrint("restored paths: \(paths), at url: \(url)")
        }
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
    private func saveBookmarkData(workDir: URL, forFolder folder: PlanetPublishedFolder) throws {
        let bookmarkData = try workDir.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: Self.prefixKey + folder.id.uuidString)
    }

    private func restoreFileAccess(with bookmarkData: Data, forFolder folder: PlanetPublishedFolder) throws -> URL {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        if isStale {
            try saveBookmarkData(workDir: url, forFolder: folder)
        }
        return url
    }
}
