//
//  LogFileTrimmer.swift
//  Planet
//

import Foundation


enum LogFileTrimmer {
    private static let maxFileSize: UInt64 = 100 * 1024 * 1024
    private static let trimTargetSize: UInt64 = 50 * 1024 * 1024

    static func trimIfNeeded(at url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? UInt64,
              fileSize > maxFileSize else { return }

        guard let readHandle = try? FileHandle(forReadingFrom: url) else { return }
        let keepOffset = fileSize - trimTargetSize
        readHandle.seek(toFileOffset: keepOffset)
        var data = readHandle.readDataToEndOfFile()
        readHandle.closeFile()

        if let newlineIndex = data.firstIndex(of: UInt8(ascii: "\n")) {
            data = data.suffix(from: data.index(after: newlineIndex))
        }

        if let writeHandle = try? FileHandle(forWritingTo: url) {
            writeHandle.seek(toFileOffset: 0)
            try? writeHandle.write(contentsOf: data)
            writeHandle.truncateFile(atOffset: writeHandle.offsetInFile)
            writeHandle.closeFile()
        }
    }
}
