//
//  IPFSLogger.swift
//  Planet
//

import Foundation


enum IPFSLogger {
    private static let logURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("ipfs.log", isDirectory: false)
    private static let queue = DispatchQueue(label: "xyz.planetable.IPFSLogger")
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
