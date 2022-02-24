//
//  Extensions.swift
//  Planet
//
//  Created by Kai on 11/10/21.
//

import Foundation
import Cocoa
import SwiftUI


extension String {
    static let currentUUIDKey: String = "PlanetCurrentUUIDKey"
    static let settingsLaunchOptionKey = "PlanetUserDefaultsLaunchOptionKey"
}


extension Notification.Name {
    static let killHelper = Notification.Name("PlanetKillPlanetHelperNotification")
    static let terminateDaemon = Notification.Name("PlanetTerminatePlanetDaemonNotification")
    static let closeWriterWindow = Notification.Name("PlanetCloseWriterWindowNotification")
    static let updateAvatar = Notification.Name("PlanetUpdateAvatarNotification")
}


extension Date {
    func dateDescription() -> String {
        let format = DateFormatter()
        format.dateStyle = .short
        format.timeStyle = .medium
        return format.string(from: self)
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
        let URLString : String = String(format: "%@?%@", self.absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString)!
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
    func imageResize(_ newSize: NSSize) -> NSImage? {
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

    func imageSave(_ filepath: URL) {
        autoreleasepool {
            guard let imageData = self.tiffRepresentation else { return }
            let imageRep = NSBitmapImageRep(data: imageData)
            let data = imageRep?.representation(using: .png, properties: [:])
            do {
                try data?.write(to: filepath, options: .atomic)
            } catch {
                debugPrint("[Image Save Error] \(error)")
            }
        }
    }
}
