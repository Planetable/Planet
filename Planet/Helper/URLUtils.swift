//
//  URLUtils.swift
//  Planet
//
//  Created by Shu Lyu on 2022-05-07.
//

import Cocoa
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

    static let legacyPlanetsPath = applicationSupportPath.appendingPathComponent(
        "planets",
        isDirectory: true
    )

    static let legacyTemplatesPath = applicationSupportPath.appendingPathComponent(
        "templates",
        isDirectory: true
    )

    static let legacyDraftPath = applicationSupportPath.appendingPathComponent(
        "drafts",
        isDirectory: true
    )

    static func repoPath() -> URL {
        if let libraryLocation = UserDefaults.standard.string(forKey: .settingsLibraryLocation),
            FileManager.default.fileExists(atPath: libraryLocation)
        {
            let libraryURL = URL(fileURLWithPath: libraryLocation)
            let planetURL = libraryURL.appendingPathComponent("Planet", isDirectory: true)
            if FileManager.default.fileExists(atPath: planetURL.path) {
                do {
                    let bookmarkKey = libraryURL.path.md5()
                    if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
                        var isStale = false
                        let url = try URL(
                            resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale
                        )
                        if isStale {
                            let updatedBookmarkData = try url.bookmarkData(
                                options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil
                            )
                            UserDefaults.standard.set(updatedBookmarkData, forKey: bookmarkKey)
                        }
                        if url.startAccessingSecurityScopedResource() {
                            return planetURL
                        }
                        else {
                            UserDefaults.standard.removeObject(forKey: .settingsLibraryLocation)
                            debugPrint(
                                "failed to start accessing security scoped resource, abort & restore to default."
                            )
                        }
                    }
                }
                catch {
                    UserDefaults.standard.removeObject(forKey: .settingsLibraryLocation)
                    debugPrint(
                        "failed to get planet library location: \(error), restore to default."
                    )
                }
            }
            else {
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
            scheme == "http" || scheme == "https"
        {
            return true
        }
        return false
    }

    var isImage: Bool {
        let ext = pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "avif", "svg", "tiff", "bmp"].contains(ext)
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

    var asNSImage: NSImage {
        let ext = pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "tiff", "bmp"].contains(ext),
            let image = NSImage(contentsOf: self)
        {
            return image
        }
        if let rep = NSWorkspace.shared.icon(forFile: self.path)
            .bestRepresentation(
                for: NSRect(x: 0, y: 0, width: 128, height: 128),
                context: nil,
                hints: nil
            )
        {
            let image = NSImage(size: rep.size)
            image.addRepresentation(rep)
            return image
        }
        return NSImage()
    }

    var isJPEG: Bool {
        return pathExtension.lowercased() == "jpg" || pathExtension.lowercased() == "jpeg"
    }

    func removeGPSInfo() {
        do {
            let data = try Data(contentsOf: self)
            let source = CGImageSourceCreateWithData(data as CFData, nil)!
            let count = CGImageSourceGetCount(source)
            let mutableData = NSMutableData()
            let destination = CGImageDestinationCreateWithData(
                mutableData,
                CGImageSourceGetType(source)!,
                count,
                nil
            )!
            for i in 0..<count {
                let image = CGImageSourceCreateImageAtIndex(source, i, nil)!
                let properties =
                    CGImageSourceCopyPropertiesAtIndex(source, i, nil) as! [CFString: Any]
                var newProperties = properties
                newProperties.removeValue(forKey: kCGImagePropertyGPSDictionary)
                // newProperties.removeValue(forKey: kCGImagePropertyExifDictionary)
                // newProperties.removeValue(forKey: kCGImagePropertyTIFFDictionary)
                CGImageDestinationAddImage(destination, image, newProperties as CFDictionary)
            }
            CGImageDestinationFinalize(destination)
            try mutableData.write(to: self)
        }
        catch {
            // Handle the error here
            print("Remove GPS Error: \(error)")
        }
    }

    var htmlCode: String {
        let name = self.lastPathComponent
        if isImage {
            if let im = NSImage(contentsOf: self) {
                let imageRep = im.representations.first as? NSBitmapImageRep
                let width = imageRep?.pixelsWide ?? 0
                let height = imageRep?.pixelsHigh ?? 0
                let pointSize = im.size
                let pointWidth = pointSize.width
                let pointHeight = pointSize.height
                var widthToUse = 0
                if (CGFloat(width) / pointWidth) > 1 {
                    widthToUse = Int(pointWidth)
                }
                else {
                    widthToUse = width
                }
            if Int(widthToUse) > 0 {
                return
                    "<img width=\"\(Int(widthToUse))\" alt=\"\((name as NSString).deletingPathExtension)\" src=\"\(name)\">"
                }
                else {
                    return "<img alt=\"\((name as NSString).deletingPathExtension)\" src=\"\(name)\">"
                }
            }
            return "<img alt=\"\((name as NSString).deletingPathExtension)\" src=\"\(name)\">"
        }
        return "<a href=\"\(name)\">\(name)</a>"
    }
}
