//
//  Extensions.swift
//  Planet
//
//  Created by Kai on 11/10/21.
//

import Foundation
import Cocoa
import CommonCrypto
import SwiftUI

extension Data {
    private func digest(input : NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }

    private func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)

        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }

        return hexString
    }

    func logFormat(encoding: String.Encoding = .utf8) -> String {
        String(data: self, encoding: encoding) ?? String(describing: self)
    }
}

public extension String {

}
extension String {
    static let currentUUIDKey: String = "PlanetCurrentUUIDKey"
    static let settingsLaunchOptionKey = "PlanetUserDefaultsLaunchOptionKey"

    func sanitized() -> String {
        // see for ressoning on charachrer sets https://superuser.com/a/358861
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        return components(separatedBy: invalidCharacters).joined(separator: "")
    }

    mutating func sanitize() -> Void {
        self = sanitized()
    }

    func whitespaceCondenced() -> String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    mutating func condenceWhitespace() -> Void {
        self = whitespaceCondenced()
    }

    func sha256() -> String {
        data(using: .utf8)!.sha256().toHexString()
    }

    func toDate() -> Date? {
        ISO8601DateFormatter().date(from: self)
    }

    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


extension Notification.Name {
    static let killHelper = Notification.Name("PlanetKillPlanetHelperNotification")
    static let terminateDaemon = Notification.Name("PlanetTerminatePlanetDaemonNotification")
    
    static let closeWriterWindow = Notification.Name("PlanetCloseWriterWindowNotification")
    static let sendArticle = Notification.Name("PlanetSendArticleNotification")
    
    static let closeTemplateBrowserWindow = Notification.Name("PlanetCloseTemplateBrowserWindowNotification")
    
    static let updateAvatar = Notification.Name("PlanetUpdateAvatarNotification")
    
    static let publishPlanet = Notification.Name("PlanetPublishPlanetNotification")
    
    static let loadArticle = Notification.Name("PlanetLoadArticleNotification")
    static let refreshArticle = Notification.Name("PlanetRefreshArticleNotification")
}


extension Date {
    func dateDescription() -> String {
        let format = DateFormatter()
        format.dateStyle = .short
        format.timeStyle = .medium
        return format.string(from: self)
    }

    func shortDateDescription() -> String {
        let format = DateFormatter()
        format.dateStyle = .none
        format.timeStyle = .medium
        return format.string(from: self)
    }

    func mmddyyyy() -> String {
        let format = DateFormatter()
        format.dateStyle = .medium
        format.timeStyle = .none
        return format.string(from: self)
    }

    func relativeDateDescription() -> String {
        let format = RelativeDateTimeFormatter()
        format.formattingContext = .standalone
        format.unitsStyle = .short
        return format.string(for: self) ?? shortDateDescription()
    }
}


extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}


protocol URLQueryParameterStringConvertible {
    var queryParameters: String {get}
}


extension Dictionary : URLQueryParameterStringConvertible {
    var queryParameters: String {
        var parts: [String] = []
        for (key, value) in self {
            let part = String(format: "%@=%@",
                String(describing: key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!,
                String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
            parts.append(part as String)
        }
        return parts.joined(separator: "&")
    }
}


extension URL {
    func appendingQueryParameters(_ parametersDictionary : Dictionary<String, String>) -> URL {
        let URLString : String = String(format: "%@?%@", absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString)!
    }

    static func relativeURL(string: String, base: URL) -> URL? {
        // Foundation.URL isn't happy when calculating URL relative to a base URL without a trailing slash
        let s = base.absoluteString
        if s.hasSuffix("/") {
            return URL(string: string, relativeTo: base)
        }
        // While browser would usually replace the last path component, in our case we just need to append a slash
        // Example:
        // In browser (https://developer.mozilla.org/en-US/docs/Web/API/URL/URL):
        // > new URL("./feed.json", "https://example.com/ignored")
        //   URL { href: "https://example.com/feed.json", ... }
        // Our case:
        // > URL.relativeURL(
        // .     string: "./feed.json",
        // .     relativeTo: "http://localhost:18181/ipfs/QmbKu58pyq3WRgWNDv9Zat39QzB7jpzgZ2iSzaXjwas4MB"
        // . )
        //   Foundation.URL = "http://localhost:18181/ipfs/QmbKu58pyq3WRgWNDv9Zat39QzB7jpzgZ2iSzaXjwas4MB/feed.json"
        let baseWithTrailingSlash = URL(string: s + "/")!
        return URL(string: string, relativeTo: baseWithTrailingSlash)
    }
}


extension UUID {
    // UUID is 128-bit, we need two 64-bit values to represent it
    var integers: (Int64, Int64) {
        var a: UInt64 = 0
        a |= UInt64(self.uuid.0)
        a |= UInt64(self.uuid.1) << 8
        a |= UInt64(self.uuid.2) << (8 * 2)
        a |= UInt64(self.uuid.3) << (8 * 3)
        a |= UInt64(self.uuid.4) << (8 * 4)
        a |= UInt64(self.uuid.5) << (8 * 5)
        a |= UInt64(self.uuid.6) << (8 * 6)
        a |= UInt64(self.uuid.7) << (8 * 7)

        var b: UInt64 = 0
        b |= UInt64(self.uuid.8)
        b |= UInt64(self.uuid.9) << 8
        b |= UInt64(self.uuid.10) << (8 * 2)
        b |= UInt64(self.uuid.11) << (8 * 3)
        b |= UInt64(self.uuid.12) << (8 * 4)
        b |= UInt64(self.uuid.13) << (8 * 5)
        b |= UInt64(self.uuid.14) << (8 * 6)
        b |= UInt64(self.uuid.15) << (8 * 7)

        return (Int64(bitPattern: a), Int64(bitPattern: b))
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 08) & 0xFF) / 255,
            blue: Double((hex >> 00) & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension NSImage {
    func resize(_ newSize: NSSize) -> NSImage? {
        autoreleasepool {
            if let bitmapRep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ) {
                bitmapRep.size = newSize
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
                draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
                NSGraphicsContext.restoreGraphicsState()
                let resizedImage = NSImage(size: newSize)
                resizedImage.addRepresentation(bitmapRep)
                return resizedImage
            }
            return nil
        }
    }
}

extension FileManager {
    func listSubdirectories(url: URL) throws -> [URL] {
        let files = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        return files.filter { fileURL in
            fileURL.hasDirectoryPath
        }
    }
}

extension HTTPURLResponse {
    var ok: Bool {
        statusCode >= 200 && statusCode < 300
    }
}

extension ProcessInfo {
    // Reference: https://developer.apple.com/forums/thread/652667
    var machineHardwareName: String? {
        var sysinfo = utsname()
        let result = uname(&sysinfo)
        guard result == EXIT_SUCCESS else { return nil }
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        guard let identifier = String(bytes: data, encoding: .ascii) else { return nil }
        return identifier.trimmingCharacters(in: .controlCharacters)
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: UInt64) async throws {
        try await sleep(nanoseconds: seconds * NSEC_PER_SEC)
    }
}

enum ViewVisibility: CaseIterable {
    case visible,   // view is fully visible
         invisible, // view is hidden but takes up space
         gone       // view is fully removed from the view hierarchy
}

extension View {
    @ViewBuilder func visibility(_ visibility: ViewVisibility) -> some View {
        if visibility != .gone {
            if visibility == .visible {
                self
            } else {
                hidden()
            }
        }
    }
}
