//
//  SSHRsyncLogger.swift
//  Planet
//

import Foundation


enum SSHRsyncLogger {
    private static let logURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("rsync.log", isDirectory: false)
    private static let queue = DispatchQueue(label: "xyz.planetable.SSHRsyncLogger")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(_ message: String) {
        queue.async {
            let timestamp = formatter.string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

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

    static var logPath: String { logURL.path }

    static func readAll() -> String {
        guard let data = try? Data(contentsOf: logURL) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: logURL)
        }
    }
}
