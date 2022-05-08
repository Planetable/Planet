//
//  URLUtils.swift
//  Planet
//
//  Created by Shu Lyu on 2022-05-07.
//

import Foundation

struct URLUtils {
    static var applicationSupportPath: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    static var basePath: URL {
        let bundleID = Bundle.main.bundleIdentifier! + ".v03"
        let path: URL
        if let p = applicationSupportPath {
            path = p.appendingPathComponent(bundleID, isDirectory: true)
        } else {
            path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Planet")
        }
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }

    static var planetsPath: URL {
        let contentPath = basePath.appendingPathComponent("planets", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }

    static var templatesPath: URL {
        let contentPath = basePath.appendingPathComponent("templates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: contentPath.path) {
            try? FileManager.default.createDirectory(at: contentPath, withIntermediateDirectories: true, attributes: nil)
        }
        return contentPath
    }
}
