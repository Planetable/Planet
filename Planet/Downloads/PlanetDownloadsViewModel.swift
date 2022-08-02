//
//  PlanetDownloadsViewModel.swift
//  Planet
//
//  Created by Kai on 8/1/22.
//

import Foundation
import WebKit
import SwiftUI


@MainActor
class PlanetDownloadsViewModel: ObservableObject {
    static let shared = PlanetDownloadsViewModel()
    
    let timer = Timer.publish(every: 0.5, tolerance: 0.1, on: .current, in: .common).autoconnect()

    @Published private(set) var downloads: [PlanetDownloadItem] = [] {
        didSet {
            // MARK: TODO: handle downloads history.
            saveDownloads()
        }
    }

    @Published var selectedDownloadID: UUID?

    init() {
        downloads = loadDownloads()
    }

    func addDownload(_ download: PlanetDownloadItem) {
        if !downloads.contains(download) {
            downloads.insert(download, at: 0)
        }
    }

    func removeAllDownloads() {
        for item in downloads {
            item.download.progress.cancel()
        }
        downloads.removeAll()
    }

    private func saveDownloads() {
    }

    private func loadDownloads() -> [PlanetDownloadItem] {
        return []
    }
}
