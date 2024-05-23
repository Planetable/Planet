//
//  IPFSMigrationCommand.swift
//  Planet
//

import Foundation


struct IPFSMigrationCommand {
    var repoName: String
    
    enum IPFSMigrationError: Error {
        case missingRepo
        case unsupportedPlatform
        case failure(code: Int32, reason: String?)
    }
    
    static func currentRepoVersion() async throws -> Int {
        /*
         ipfs repo version -> kubo versions
         12 -> 0.12.0 - 0.17.0
         13 -> 0.18.0 - 0.20.0
         14 -> 0.21.0 - 0.22.0
         15 -> 0.23.0 - 0.28 (current)
         */
        let repoPath = IPFSCommand.IPFSRepositoryPath
        let versionPath = repoPath.appendingPathComponent("version")
        let versionData = try Data(contentsOf: versionPath)
        guard let versionString = String(data: versionData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw IPFSMigrationError.missingRepo
        }
        if let version: Int = Int(versionString) {
            return version
        }
        throw IPFSMigrationError.missingRepo
    }
    
    static func migrationRepoNames(forRepoVersion version: Int) -> [String] {
        switch version {
        case 12:
            return [
                "fs-repo-12-to-13",
                "fs-repo-13-to-14",
                "fs-repo-14-to-15"
            ]
        case 13:
            return [
                "fs-repo-13-to-14",
                "fs-repo-14-to-15"
            ]
        case 14:
            return [
                "fs-repo-14-to-15"
            ]
        default:
            return []
        }
    }

    @MainActor
    func run() async throws -> Data {
        let executableURL: URL = try {
            switch ProcessInfo.processInfo.machineHardwareName {
            case "arm64":
                return Bundle.main.url(forResource: "\(repoName)_arm64", withExtension: nil)!
            case "x86_64":
                return Bundle.main.url(forResource: "\(repoName)_amd64", withExtension: nil)!
            default:
                throw IPFSMigrationError.unsupportedPlatform
            }
        }()
        let targetRepoPath = IPFSCommand.IPFSRepositoryPath.path
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()
                
                task.standardOutput = pipe
                task.standardError = errorPipe

                task.executableURL = executableURL
                task.arguments = [
                    "-path", targetRepoPath
                ]
            
                do  {
                    try task.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: data)
                } catch {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8)
                    let returnCode = task.terminationStatus
                    continuation.resume(throwing: IPFSMigrationError.failure(code: returnCode, reason: errorString))
                }
            }
        }
    }
}
