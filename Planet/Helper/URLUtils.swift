//
//  URLUtils.swift
//  Planet
//
//  Created by Shu Lyu on 2022-05-07.
//

import Foundation

struct URLUtils {
    static let applicationSupportPath = try! FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )

    static let documentsPath = try! FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )

    static let cachesPath = try! FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )

    static let legacyPlanetsPath = applicationSupportPath.appendingPathComponent("planets", isDirectory: true)

    static let legacyTemplatesPath = applicationSupportPath.appendingPathComponent("templates", isDirectory: true)

    static let legacyDraftPath = applicationSupportPath.appendingPathComponent("drafts", isDirectory: true)

    static func repoPath() -> URL {
        if let libraryLocation = UserDefaults.standard.string(forKey: .settingsLibraryLocation), FileManager.default.fileExists(atPath: libraryLocation) {
            let libraryURL = URL(fileURLWithPath: libraryLocation)
            let planetURL = libraryURL.appendingPathComponent("Planet", isDirectory: true)
            if FileManager.default.fileExists(atPath: planetURL.path) {
                do {
                    let bookmarkKey = libraryURL.path.md5()
                    if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
                        var isStale = false
                        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                        if isStale {
                            let updatedBookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                            UserDefaults.standard.set(updatedBookmarkData, forKey: bookmarkKey)
                        }
                        if url.startAccessingSecurityScopedResource() {
                            return planetURL
                        } else {
                            UserDefaults.standard.removeObject(forKey: .settingsLibraryLocation)
                            debugPrint("failed to start accessing security scoped resource, abort & restore to default.")
                        }
                    }
                } catch {
                    UserDefaults.standard.removeObject(forKey: .settingsLibraryLocation)
                    debugPrint("failed to get planet library location: \(error), restore to default.")
                }
            } else {
                UserDefaults.standard.removeObject(forKey: .settingsLibraryLocation)
            }
        }
        return Self.defaultRepoPath
    }
    
    static let defaultRepoPath: URL = {
        let url = Self.documentsPath.appendingPathComponent("Planet", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let temporaryPath: URL = {
        let url = Self.cachesPath.appendingPathComponent("tmp", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
}

extension URL {
    var isHTTP: Bool {
        if let scheme = scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return true
        }
        return false
    }

    var pathQueryFragment: String {
        var s = path
        if let query = query {
            s += "?\(query)"
        }
        if let fragment = fragment {
            s += "#\(fragment)"
        }
        return s
    }

    var isPlanetLink: Bool {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        if components?.scheme == "planet" && !isPlanetWindowGroupLink {
            return true
        }
        return false
    }

    var isPlanetWindowGroupLink: Bool {
        let windowGroups: [String] = ["planet://Template"]
        return windowGroups.contains(self.absoluteString)
    }
}
