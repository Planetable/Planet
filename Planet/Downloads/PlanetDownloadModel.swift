//
//  PlanetDownloadModel.swift
//  Planet
//
//  Created by Kai on 8/1/22.
//

import Foundation
import WebKit


enum PlanetDownloadItemStatus: Int {
    case idle
    case downloading
    case finished
    case paused
    case cancelled
}


struct PlanetDownloadItem: Identifiable, Hashable {
    var id: UUID
    var created: Date
    var download: WKDownload
}


extension PlanetDownloadItem {
    func downloadItemName() -> String {
        return download.progress.fileURL?.lastPathComponent ?? "planet.default.download"
    }
}
