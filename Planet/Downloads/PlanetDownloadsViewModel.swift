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
    
    let timer = Timer.publish(every: 1, tolerance: 0.25, on: .current, in: .common).autoconnect()

    @Published private(set) var downloads: [PlanetDownloadItem] = [] {
        didSet {
            // MARK: TODO: deal with downloads history.
        }
    }

    @Published var selectedDownloadID: UUID?

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
}
