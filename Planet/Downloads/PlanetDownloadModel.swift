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
            "application/atom+xml",
            "application/epub+zip",
            "application/gzip",
            "application/msword",
            "application/json",
            "application/octet-stream",
            "application/pdf",
            "application/rss+xml",
            "application/vnd.apple.installer+xml",
            "application/vnd.ms-powerpoint",
            "application/vnd.rar",
            "application/x-7z-compressed",
            "application/x-tar",
            "application/xml",
            "application/zip",
            "audio/aac",
            "audio/mpeg",
            "audio/ogg",
            "audio/wav",
            "audio/webm",
            "font/ttf",
            "image/gif",
            "image/jpeg",
            "image/png",
            "image/svg+xml",
            "image/tiff",
            "image/webp",
            "text/csv",
            "video/mp4",
            "video/mpeg",
            "video/ogg",
            "video/webm",
            "video/x-msvideo"
        ]
    }

    static func downloadableFileExtensions() -> [String] {
        return [
            "3g2",
            "3gp",
            "7z",
            "ai",
            "aif",
            "apk",
            "arj",
            "avi",
            "bak",
            "bat",
            "bin",
            "bmp",
            "c",
            "cab",
            "cda",
            "cer",
            "cfg",
            "cfm",
            "cgi",
            "class",
            "com",
            "cpl",
            "cpp",
            "cs",
            "css",
            "csv",
            "cur",
            "dat",
            "db",
            "dbf",
            "deb",
            "dll",
            "dmg",
            "dmp",
            "doc",
            "docx",
            "drv",
            "eml",
            "emlx",
            "exe",
            "flv",
            "fnt",
            "fon",
            "gadget",
            "gif",
            "h",
            "h264",
            "icns",
            "ico",
            "ini",
            "iso",
            "jar",
            "java",
            "jpeg",
            "jpg",
            "json",
            "js",
            "jsp",
            "key",
            "lnk",
            "log",
            "m4v",
            "mdb",
            "mid",
            "midi",
            "mkv",
            "mov",
            "mp3",
            "mp4",
            "mpa",
            "mpeg",
            "mpg",
            "msg",
            "msi",
            "msi",
            "odp",
            "ods",
            "odt",
            "oft",
            "ogg",
            "ost",
            "otf",
            "pdf",
            "pkg",
            "pl",
            "pl",
            "png",
            "pps",
            "ppt",
            "pptx",
            "ps",
            "psd",
            "pst",
            "py",
            "rar",
            "rm",
            "rpm",
            "rss",
            "rtf",
            "sav",
            "sh",
            "sql",
            "svg",
            "swf",
            "sys",
            "tar",
            "tar.gz",
            "tex",
            "tif",
            "tiff",
            "tmp",
            "toast",
            "ttf",
            "txt",
            "vb",
            "vcd",
            "vcf",
            "vob",
            "wav",
            "webp",
            "wma",
            "wmv",
            "wpd",
            "wpl",
            "wsf",
            "xls",
            "xlsm",
            "xlsx",
            "xml",
            "z",
            "zip"
        ]
    }
}
