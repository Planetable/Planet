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
    static let removedListKey = "PlanetPublishedFolderRemovalList"

    let timer = Timer.publish(every: 3, tolerance: 0.1, on: .current, in: RunLoop.Mode.default).autoconnect()

    @Published var timestamp: Int = Int(Date().timeIntervalSince1970)
    @Published private(set) var publishedFolders: [PlanetPublishedFolder] = []
    @Published private(set) var publishingFolders: [UUID] = []

    init() {
        do {
            publishedFolders = try loadPublishedFolders()
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                Task(priority: .background) {
                    let removedIDs: [String] = UserDefaults.standard.stringArray(forKey: Self.removedListKey) ?? []
                    for id in removedIDs {
                        do {
                            try await self.unpublishFolder(keyName: id)
                        } catch {
                            debugPrint("failed to unpublish folder with key id: \(id), error: \(error)")
                        }
                    }
                }
            }
        } catch {
            debugPrint("failed to load published folders: \(error)")
        }
    }

    func addToRemovingPublishedFolderQueue(_ folder: PlanetPublishedFolder) {
        removeBookmarkData(forFolder: folder)
        let isPublished: Bool = folder.publishedLink != nil && folder.published != nil
        if !isPublished {
            return
        }
        Task(priority: .background) {
            do {
                try await unpublishFolder(keyName: folder.id.uuidString)
            } catch {
                debugPrint("failed to unpublish folder: \(folder), error: \(error)")
            }
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

    private func unpublishFolder(keyName: String) async throws {
        debugPrint("Removing published folder with key id: \(keyName) ...")
        // 1. save removed id list in case unpublishing process was interupt
        var removedIDs: [String] = UserDefaults.standard.stringArray(forKey: Self.removedListKey) ?? []
        if !removedIDs.contains(keyName) {
            removedIDs.append(keyName)
            UserDefaults.standard.set(removedIDs, forKey: Self.removedListKey)
        }

        // 2. publish the empty folder
        let emptyFolderURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(keyName)
        if FileManager.default.fileExists(atPath: emptyFolderURL.path) {
            try? FileManager.default.removeItem(at: emptyFolderURL)
        }
        try? FileManager.default.createDirectory(at: emptyFolderURL, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: emptyFolderURL.path) else { return }

        let updatedRemovedIDs = removedIDs
        let keyExists = try await IPFSDaemon.shared.checkKeyExists(name: keyName)
        guard keyExists else { throw PlanetError.InternalError }
        let cid = try await IPFSDaemon.shared.addDirectory(url: emptyFolderURL)
        let result = try await IPFSDaemon.shared.api(
            path: "name/publish",
            args: [
                "arg": cid,
                "allow-offline": "1",
                "key": keyName,
                "quieter": "1",
                "lifetime": "7200h",
            ],
            timeout: 600
        )
        let deocder = JSONDecoder()
        let publishedStatus = try deocder.decode(IPFSPublished.self, from: result)

        // 3. update removal list if unpublished
        if publishedStatus.name != "" {
            try await IPFSDaemon.shared.removeKey(name: keyName)
            UserDefaults.standard.set(updatedRemovedIDs.filter({ id in
                return id != keyName
            }), forKey: Self.removedListKey)
            debugPrint("Folder with key id \(keyName) is unpublished and removed -> \(publishedStatus)")
        }
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
