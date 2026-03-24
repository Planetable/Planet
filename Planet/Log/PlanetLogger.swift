//
//  PlanetLogger.swift
//  Planet
//

import Foundation


enum PlanetLogger {
    private static let logURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("planet.log", isDirectory: false)
    private static let queue = DispatchQueue(label: "xyz.planetable.PlanetLogger")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(_ message: String) {
        queue.async {
            let normalized = message.replacingOccurrences(of: "\r\n", with: "\n")
            let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
            guard !lines.isEmpty else { return }

            let timestamp = formatter.string(from: Date())
            let payload = lines.map { "[\(timestamp)] \($0)" }.joined(separator: "\n") + "\n"
            guard let data = payload.data(using: .utf8) else { return }

            if !FileManager.default.fileExists(atPath: logURL.path) {
                _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }

            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        }
    }

    static func log(_ message: String, level: Level) {
        log("[\(level.rawValue)] \(message)")
    }

    static var logPath: String { logURL.path }

    static func readAll() -> String {
        guard let data = try? Data(contentsOf: logURL) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func clear() {
        queue.async {
            // Truncate instead of deleting so the file inode stays the same
            // and DispatchSource file monitoring continues to work.
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.truncateFile(atOffset: 0)
                handle.closeFile()
            }
        }
    }

    enum Level: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}
