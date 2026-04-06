//
//  URLUtils.swift
//  Planet
//
//  Created by Shu Lyu on 2022-05-07.
//

import Cocoa
import Foundation
import ImageIO

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

struct AIEndpointSecurityPolicy {
    private static let allowedInsecureIPv4Ranges: [(network: UInt32, mask: UInt32)] = [
        (network: 0x7F000000, mask: 0xFF000000),
        (network: 0x0A000000, mask: 0xFF000000),
        (network: 0x64000000, mask: 0xFF000000),
        (network: 0xC0A80000, mask: 0xFFFF0000),
    ]

    static let insecureHTTPErrorDescription =
        "HTTP AI endpoints are only allowed for localhost, 127.0.0.0/8, 10.0.0.0/8, 100.0.0.0/8, and 192.168.0.0/16. Use HTTPS for other hosts."

    static func modelsURL(base: String) throws -> URL {
        try endpointURL(base: base, pathComponents: ["models"])
    }

    static func chatCompletionsURL(base: String) throws -> URL {
        try endpointURL(base: base, pathComponents: ["chat", "completions"])
    }

    private static func endpointURL(base: String, pathComponents: [String]) throws -> URL {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmedBase) else {
            throw validationError("Invalid URL")
        }
        guard let scheme = baseURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw validationError("Invalid URL")
        }
        guard let host = baseURL.host?.lowercased(), !host.isEmpty else {
            throw validationError("Invalid URL")
        }
        if scheme == "http" && !isAllowedInsecureHost(host) {
            throw validationError(insecureHTTPErrorDescription)
        }
        return pathComponents.reduce(baseURL) { partialURL, pathComponent in
            partialURL.appendingPathComponent(pathComponent)
        }
    }

    private static func isAllowedInsecureHost(_ host: String) -> Bool {
        if host == "localhost" {
            return true
        }
        guard let address = ipv4Address(host) else {
            return false
        }
        return allowedInsecureIPv4Ranges.contains { range in
            (address & range.mask) == range.network
        }
    }

    private static func ipv4Address(_ host: String) -> UInt32? {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else {
            return nil
        }

        var address: UInt32 = 0
        for octet in octets {
            guard let value = UInt8(String(octet)) else {
                return nil
            }
            address = (address << 8) | UInt32(truncatingIfNeeded: value)
        }
        return address
    }

    private static func validationError(_ description: String) -> NSError {
        NSError(
            domain: "PlanetAIEndpointSecurityPolicy",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
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
        let windowGroups: [String] = [
            "planet://Template"
        ]
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
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            let count = CGImageSourceGetCount(source)
            guard let type = CGImageSourceGetType(source) else { return }
            let mutableData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                mutableData,
                type,
                count,
                nil
            ) else { return }
            for i in 0..<count {
                guard let image = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                let properties =
                    CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] ?? [:]
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

    var imagePixelWidth: Int? {
        if let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
           pixelWidth > 0
        {
            // Retina screenshots from macOS/iOS use 144 DPI (2x) or 216 DPI (3x).
            // For these, return the logical (point) width so they display at intended size.
            // Everything else (72 DPI, 300 DPI print, etc.) uses raw pixel width.
            if let dpi = (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue, dpi > 0 {
                let scale = dpi / 72
                if scale == 2 || scale == 3 {
                    return pixelWidth / scale
                }
            }
            return pixelWidth
        }

        return NSImage(contentsOf: self)?
            .representations
            .compactMap { ($0 as? NSBitmapImageRep)?.pixelsWide }
            .first(where: { $0 > 0 })
    }

    var htmlCode: String {
        let name = self.lastPathComponent
        if isImage {
            if let width = imagePixelWidth, width > 0 {
                return
                    "<img width=\"\(width)\" alt=\"\((name as NSString).deletingPathExtension)\" src=\"\(name)\">"
            }
            return "<img alt=\"\((name as NSString).deletingPathExtension)\" src=\"\(name)\">"
        }
        return "<a href=\"\(name)\">\(name)</a>"
    }
}
