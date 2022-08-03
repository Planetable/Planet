//
//  PlanetDownloadModel.swift
//  Planet
//
//  Created by Kai on 8/1/22.
//

import Foundation
import WebKit


enum PlanetDownloadItemStatus: Int {
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
    
    static func downloadableMIMETypes() -> [String] {
        return [
            "application/pdf",
            "image/jpeg",
            "image/png",
            "audio/aac",
            "video/x-msvideo",
            "application/msword",
            "text/csv",
            "application/epub+zip",
            "application/gzip",
            "image/gif",
            "audio/mpeg",
            "video/mp4",
            "video/mpeg",
            "application/vnd.apple.installer+xml",
            "audio/ogg",
            "video/ogg",
            "application/vnd.ms-powerpoint",
            "application/vnd.rar",
            "image/svg+xml",
            "application/x-tar",
            "image/tiff",
            "font/ttf",
            "audio/wav",
            "audio/webm",
            "video/webm",
            "image/webp",
            "application/zip",
            "application/x-7z-compressed",
            "application/octet-stream"
        ]
    }
}
