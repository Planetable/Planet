//
//  PlanetImportViewModel.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import SwiftUI


class PlanetImportViewModel: ObservableObject {
    static let shared = PlanetImportViewModel()

    @Published private(set) var markdownURLs: [URL] = []
    @Published private(set) var importUUID: UUID = UUID()

    @MainActor
    func updateMarkdownURLs(_ urls: [URL]) {
        importUUID = UUID()
        markdownURLs = urls
    }

    func processAndImport() async throws {
        let url = try importDirectory()
        // analyze and process each file.
    }

    func cleanup() {
        
    }

    // MARK: -

    private func importDirectory() throws -> URL {
        let tempURL = URLUtils.temporaryPath.appendingPathComponent("ImportMarkdownFiles")
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        }
        let importURL = tempURL.appendingPathComponent(importUUID.uuidString)
        if FileManager.default.fileExists(atPath: importURL.path) {
            try FileManager.default.removeItem(at: importURL)
        }
        try FileManager.default.createDirectory(at: importURL, withIntermediateDirectories: true)
        return importURL
    }
}
