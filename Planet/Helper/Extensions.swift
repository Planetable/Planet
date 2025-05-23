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
    static let settingsLibraryLocation: String = "PlanetSettingsLibraryLocationKey"
    static let settingsPublicGatewayIndex: String = "PlanetSettingsPublicGatewayIndexKey"
    static let settingsPreferredIPFSPublicGateway: String = "PlanetSettingsPreferredIPFSPublicGatewayKey"
    static let settingsWarnBeforeQuitIfPublishing: String = "PlanetSettingsWarnBeforeQuitIfPublishingKey"
    static let settingsEthereumChainId: String = "PlanetSettingsEthereumChainId"
    static let settingsEthereumTipAmount: String = "PlanetSettingsEthereumTipAmount"
    static let settingsAPIEnabled: String = "PlanetSettingsAPIEnabledKey"
    static let settingsAPIUsesPasscode: String = "PlanetSettingsAPIUsesPasscodeKey"
    static let settingsAPIPort: String = "PlanetSettingsAPIPortKey"
    static let settingsAPIUsername: String = "PlanetSettingsAPIUsernameKey"
    static let settingsAPIPasscode: String = "PlanetSettingsAPIPasscodeKey"

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

    func startsWithInternalGateway() -> Bool {
        let pattern = #"^http:\/\/127\.0\.0\.1:181[0-9]{2}\/"#
        let result = self.range(
            of: pattern,
            options: .regularExpression
        )
        return result != nil
    }

    func shortWalletAddress() -> String {
        let firstPart = String(self.prefix(5))
        let lastPart = String(self.suffix(4))
        return "\(firstPart)...\(lastPart)"
    }

    func shortIPNS() -> String {
        let firstPart = String(self.prefix(3))
        let lastPart = String(self.suffix(4))
        return "\(firstPart)...\(lastPart)"
    }

    func hasCommonTLDSuffix() -> Bool {
        let commonTLDs = [".com", ".co", ".net", ".org", ".io", ".xyz"]
        for tld in commonTLDs {
            if self.hasSuffix(tld) {
                return true
            }
        }
        return false
    }

    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func normalizedTag() -> String {
        // Convert to lowercase and decompose accented characters
        let decomposed = self.lowercased().folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)

        // Define a character set for unwanted characters including punctuation, whitespaces, and symbols
        let unwantedChars = CharacterSet.punctuationCharacters
            .union(.whitespacesAndNewlines)
            .union(.symbols)
            .subtracting(CharacterSet(charactersIn: "-")) // Ensure '-' is not considered unwanted

        // Separate the string by unwanted characters
        let components = decomposed.components(separatedBy: unwantedChars)

        // Join using dashes
        var tag = components.joined(separator: "-")

        // Combine multiple dashes into one
        tag = tag.replacingOccurrences(of: "--+", with: "-", options: .regularExpression)

        // Drop first and last dash if exists
        let trimmedTag = tag.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return trimmedTag
    }

    func width(usingFont font: Font) -> CGFloat {
        let nsFont: NSFont

        // Map SwiftUI Font to NSFont
        switch font {
        case .largeTitle:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize * 1.5, weight: .regular)
        case .title:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize * 1.4, weight: .regular)
        case .headline:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize * 1.2, weight: .semibold)
        case .subheadline:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize * 1.1, weight: .regular)
        case .body:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        case .callout:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize * 1.1, weight: .regular)
        case .footnote:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize * 0.9, weight: .regular)
        case .caption:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize * 0.8, weight: .regular)
        // Add other cases as needed
        default:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: nsFont]
        let size = (self as NSString).size(withAttributes: attributes)
        return size.width
    }
    
    func sqlEscaped() -> String {
        return self.replacingOccurrences(of: "'", with: "''")
    }
}

// User Notification
extension String {
    static let readArticleAlert = "PlanetReadArticleNotification"
    static let showPlanetAlert = "PlanetShowPlanetNotification"
}

// Planet Lite App Name
extension String {
    // TODO: Control this with a xcconfig
    static let liteAppName = "Croptop"
}

extension Notification.Name {
    static let killHelper = Notification.Name("PlanetKillPlanetHelperNotification")
    static let terminateDaemon = Notification.Name("PlanetTerminatePlanetDaemonNotification")

    static let closeWriterWindow = Notification.Name("PlanetCloseWriterWindowNotification")
    static let sendArticle = Notification.Name("PlanetSendArticleNotification")
    static let attachVideo = Notification.Name("PlanetAttachVideoNotification")
    static let attachPhoto = Notification.Name("PlanetAttachPhotoNotification")

    static let updateAvatar = Notification.Name("PlanetUpdateAvatarNotification")

    static let loadArticle = Notification.Name("PlanetLoadArticleNotification")
    static let publishMyPlanet = Notification.Name("PlanetPublishMyPlanetNotification")

    static let updateRuleList = Notification.Name("PlanetUpdateArticleViewRuleList")

    static let downloadArticleAttachment = Notification.Name("PlanetDownloadArticleAttachmentNotification")

    static let followingArticleReadChanged = Notification.Name("PlanetFollowingArticleReadChangedNotification")

    static let myArticleBuilt = Notification.Name("PlanetMyArticleBuiltNotification")

    static let copiedIPNS = Notification.Name("PlanetCopiedIPNSNotification")

    static let scrollToTopArticleList = Notification.Name("PlanetScrollToTopArticleListNotification")
    static let scrollToArticle = Notification.Name("PlanetScrollToArticleNotification")
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
    static let close = Notification.Name("PlanetWriterCloseWindowNotification")

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

    func simpleDateDescription() -> String {
        let format = DateFormatter()
        format.dateStyle = .medium
        format.timeStyle = .short
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

    func sanitizedLink() -> String {
        if self.fragment != nil {
            let s = self.standardized.absoluteString
            let components = s.components(separatedBy: "#")
            return components[0]
        } else {
            return self.standardized.absoluteString
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

extension Array where Element: Equatable {
    mutating func removeFirst(item: Element) -> Element? {
        if let index = firstIndex(of: item) {
            return remove(at: index)
        }
        return nil
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
