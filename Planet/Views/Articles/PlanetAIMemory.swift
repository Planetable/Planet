//
//  PlanetAIMemory.swift
//  Planet
//

import Foundation

/// Persistent memory for AI chat, stored as Workspace/MEMORY.md at the Planet library root.
enum PlanetAIMemory {
    static let workspaceFolderName = "Workspace"
    static let memoryFileName = "MEMORY.md"

    /// Cap how much of MEMORY.md gets inlined into the system prompt.
    private static let maxPromptLength = 24_000

    private static let seedContent = """
    # Memory

    Notes for the Planet AI assistant to remember across conversations.
    Edit this file freely, or ask the assistant in a chat to remember something; \
    it reads this file at the start of every chat.

    """

    static var workspaceURL: URL {
        URLUtils.repoPath().appendingPathComponent(workspaceFolderName, isDirectory: true)
    }

    static var memoryFileURL: URL {
        workspaceURL.appendingPathComponent(memoryFileName)
    }

    @discardableResult
    static func ensureMemoryFile() -> URL {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: workspaceURL.path) {
            try? fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: memoryFileURL.path) {
            try? seedContent.write(to: memoryFileURL, atomically: true, encoding: .utf8)
        }
        return memoryFileURL
    }

    /// Memory contents to inline into a chat system prompt, or nil when there is nothing to apply.
    static func loadForPrompt() -> String? {
        ensureMemoryFile()
        guard let raw = try? String(contentsOf: memoryFileURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if trimmed.count > maxPromptLength {
            return String(trimmed.prefix(maxPromptLength))
                + "\n\n[MEMORY.md truncated; read Workspace/MEMORY.md for the full contents.]"
        }
        return trimmed
    }

    /// Append a dated note to MEMORY.md. Returns the new total length in characters.
    @discardableResult
    static func appendNote(_ note: String) throws -> Int {
        ensureMemoryFile()
        var content = (try? String(contentsOf: memoryFileURL, encoding: .utf8)) ?? ""
        if !content.isEmpty, !content.hasSuffix("\n") {
            content += "\n"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let entry = note.trimmingCharacters(in: .whitespacesAndNewlines)
        content += "- [\(formatter.string(from: Date()))] \(entry)\n"
        try content.write(to: memoryFileURL, atomically: true, encoding: .utf8)
        return content.count
    }

    /// Replace the entire MEMORY.md. Returns the new total length in characters.
    @discardableResult
    static func replaceContent(_ newContent: String) throws -> Int {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: workspaceURL.path) {
            try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        }
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = trimmed.isEmpty ? seedContent : trimmed + "\n"
        try content.write(to: memoryFileURL, atomically: true, encoding: .utf8)
        return content.count
    }
}
