//
//  URLUtils.swift
//  Planet
//
//  Created by Shu Lyu on 2022-05-07.
//

import Foundation
import Cocoa

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

    var asNSImage: NSImage {
        let ext = pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "tiff", "bmp"].contains(ext),
           let image = NSImage(contentsOf: self) {
            return image
        }
        if let rep = NSWorkspace.shared.icon(forFile: self.path)
            .bestRepresentation(for: NSRect(x: 0, y: 0, width: 128, height: 128), context: nil, hints: nil) {
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
        // Check if the URL is a file URL and the file exists
        guard self.isFileURL, FileManager.default.fileExists(atPath: self.path) else {
            print("Invalid file URL or file does not exist.")
            return
        }

        // Create a CGImageSource from the input JPEG file
        guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil) else {
            print("Failed to create image source.")
            return
        }

        // Get image properties
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            print("Failed to get image properties.")
            return
        }

        // Check if GPS data is present
        if let gpsData = imageProperties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            print("GPS data found: \(gpsData)")
        } else {
            print("No GPS data found.")
            return
        }

        // Create a mutable copy of the image properties
        let mutableProperties = NSMutableDictionary(dictionary: imageProperties)

        // Remove GPS data
        mutableProperties.removeObject(forKey: kCGImagePropertyGPSDictionary)

        // Generate a unique temporary file name using UUID
        let uuid = UUID().uuidString
        let tempURL = self.deletingLastPathComponent().appendingPathComponent("\(uuid)_image_without_gps.jpg")

        // Create an image destination to save the modified image
        guard let imageDestination = CGImageDestinationCreateWithURL(tempURL as CFURL, CGImageSourceGetType(imageSource)!, 1, nil) else {
            print("Failed to create image destination.")
            return
        }

        // Add the image with modified properties (without GPS data) to the destination
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, mutableProperties)

        // Finalize the image destination to write the data to disk
        if !CGImageDestinationFinalize(imageDestination) {
            print("Failed to finalize the image destination.")
            return
        }

        // Replace the original file with the modified file
        do {
            try FileManager.default.removeItem(at: self)
            try FileManager.default.moveItem(at: tempURL, to: self)
            print("GPS data removed successfully.")
        } catch {
            print("Error replacing original file: \(error)")
        }
    }
}
