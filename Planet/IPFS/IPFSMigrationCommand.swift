//
//  IPFSMigrationCommand.swift
//  Planet
//

import Foundation


struct IPFSMigrationCommand {
    var repoName: String
    
    enum IPFSMigrationError: Error {
        case failure(code: Int32, reason: String?)
    }
    
    @MainActor
    static func currentKuboVersion() async throws -> String {
        debugPrint("checking kubo version...")
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()
                
                task.standardOutput = pipe
                task.standardError = errorPipe

                task.executableURL = IPFSCommand.IPFSExecutablePath
                
                var env = ProcessInfo.processInfo.environment
                env["IPFS_PATH"] = IPFSCommand.IPFSRepositoryPath.path
                task.environment = env
                
                do  {
                    try task.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let dataString = String(data: data, encoding: .utf8)
                    debugPrint("got version: \(dataString)")
                    continuation.resume(returning: dataString ?? "")
                } catch {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8)
                    let returnCode = task.terminationStatus
                    debugPrint("not got version: \(errorString) -> \(returnCode)")
                    continuation.resume(throwing: IPFSMigrationError.failure(code: returnCode, reason: errorString))
                }
                debugPrint("checking kubo version ...")
            }
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
                throw IPFSMigrationError.failure(code: 999, reason: "Planet is not supported on your operating system.")
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
                    "-path", targetRepoPath,
                    "-revert"
                ]

                var env = ProcessInfo.processInfo.environment
                env["IPFS_PATH"] = IPFSCommand.IPFSRepositoryPath.path
                task.environment = env
                
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
