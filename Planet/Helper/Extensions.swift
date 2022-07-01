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
    func logFormat(encoding: String.Encoding = .utf8) -> String {
        String(data: self, encoding: encoding) ?? String(describing: self)
    }
}

extension String {
    func sanitized() -> String {
        // Reference: https://superuser.com/a/358861
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        return components(separatedBy: invalidCharacters).joined(separator: "")
    }

    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func removePrefix(until: Int) -> String {
        String(suffix(from: index(startIndex, offsetBy: until)))
    }
}

extension Notification.Name {
    static let killHelper = Notification.Name("PlanetKillPlanetHelperNotification")
    static let terminateDaemon = Notification.Name("PlanetTerminatePlanetDaemonNotification")

    static let closeWriterWindow = Notification.Name("PlanetCloseWriterWindowNotification")
    static let sendArticle = Notification.Name("PlanetSendArticleNotification")
    static let attachVideo = Notification.Name("PlanetAttachVideoNotification")
    static let attachPhoto = Notification.Name("PlanetAttachPhotoNotification")

    static let closeTemplateBrowserWindow = Notification.Name("PlanetCloseTemplateBrowserWindowNotification")

    static let updateAvatar = Notification.Name("PlanetUpdateAvatarNotification")

    static let publishPlanet = Notification.Name("PlanetPublishPlanetNotification")

    static let loadArticle = Notification.Name("PlanetLoadArticleNotification")
}

// Writer
extension Notification.Name {
    static let clearText = Notification.Name("PlanetWriterClearTextNotification")
    static let insertText = Notification.Name("PlanetWriterInsertTextNotification")
    static let removeText = Notification.Name("PlanetWriterRemoveTextNotification")
    static let moveCursorFront = Notification.Name("PlanetWriterMoveCursorFrontNotification")
    static let moveCursorEnd = Notification.Name("PlanetWriterMoveCursorEndNotification")
    static let loadPreview = Notification.Name("PlanetWriterLoadDraftPreviewNotification")
    static let pauseMedia = Notification.Name("PlanetWriterPauseMediaNotification")

    static func writerNotification(_ notification: Notification.Name, for draft: DraftModel) -> Notification.Name {
        Notification.Name(notification.rawValue + "-" + draft.id.uuidString)
    }
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

extension Array where Element: Equatable {
    mutating func removeFirst(item: Element) -> Element? {
        if let index = firstIndex(of: item) {
            return remove(at: index)
        }
        return nil
    }
}
