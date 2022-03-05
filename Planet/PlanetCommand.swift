//
//  PlanetCommandCore.swift
//  Planet
//
//  Created by Kai on 11/9/21.
//

import Foundation
import Dispatch


/**
 *  Run IPFS commands
 *
 *  - parameter command: The command with launch path, config path and arguments
 *  - parameter process: The process to use to perform the command. default: New one every command
 *  - parameter outputHandle: Any `FileHandle` that any output (STDOUT) should be redirected to
 *              (at the moment this is only supported on macOS)
 *  - parameter errorHandle: Any `FileHandle` that any error output (STDERR) should be redirected to
 *              (at the moment this is only supported on macOS)
 *  - returns: The output of running the command
 *  - throws: `PlanetCommandError` in case the command couldn't be performed, or it returned an error
 *
 */
@discardableResult func runCommand(
    command: PlanetCommand,
    process: Process = .init(),
    outputHandle: FileHandle? = nil,
    errorHandle: FileHandle? = nil
) throws -> [String: Any] {
    var argus: [String] = command.arguments
    if command.configPath != "" {
        argus.append("-c")
        argus.append(command.configPath)
        argus.append("--enc")
        argus.append("json")
    }
    return try process.launchCommand(command: command.command, withArguments: argus, andConfigPath: command.configPath, outputHandle: outputHandle, errorHandle: errorHandle)
}


// MARK: - PlanetCommand
struct PlanetCommand {
    let command: String
    let arguments: [String]
    let configPath: String
    let timeout: Int

    init(command: String, arguments: [String], configPath: String, timeout: Int = 0) {
        self.command = command
        self.arguments = arguments
        self.configPath = configPath
        self.timeout = timeout
    }
}

extension PlanetCommand {
    static func ipfsInit(target: URL, config: URL) -> PlanetCommand {
        let cmd = PlanetCommand(command: target.path, arguments: ["init"], configPath: config.path)
        return cmd
    }

    static func ipfsGetID(target: URL, config: URL) -> PlanetCommand {
        let cmd = PlanetCommand(command: target.path, arguments: ["id"], configPath: config.path)
        return cmd
    }

    static func ipfsAddDirectory(target: URL, config: URL, directory: URL) -> PlanetCommand {
        var params: [String] = []
        params.append("add")
        params.append("-r")
        params.append(directory.path)
        params.append("--cid-version")
        params.append("1")
        params.append("--quieter")
        let cmd = PlanetCommand(command: target.path, arguments: params, configPath: config.path)
        return cmd
    }

    static func ipfsUpdateAPIPort(target: URL, config: URL, port: String) -> PlanetCommand {
        let cmd = PlanetCommand(command: target.path, arguments: ["config", "Addresses.API", "/ip4/127.0.0.1/tcp/\(port)"], configPath: config.path)
        return cmd
    }

    static func ipfsUpdateGatewayPort(target: URL, config: URL, port: String) -> PlanetCommand {
        let cmd = PlanetCommand(command: target.path, arguments: ["config", "Addresses.Gateway", "/ip4/127.0.0.1/tcp/\(port)"], configPath: config.path)
        return cmd
    }

    static func ipfsUpdateSwarmPort(target: URL, config: URL, port: String) -> PlanetCommand {
        let cmd = PlanetCommand(command: target.path, arguments: ["config", "Addresses.Swarm", "[\"/ip4/0.0.0.0/tcp/\(port)\", \"/ip6/::/tcp/\(port)\", \"/ip4/0.0.0.0/udp/\(port)/quic\", \"/ip6/::/udp/\(port)/quic\"]", "--json"], configPath: config.path)
        return cmd
    }

    static func ipfsLaunchDaemon(target: URL, config: URL) -> PlanetCommand {
        let cmd = PlanetCommand(command: target.path, arguments: ["daemon", "--enable-namesys-pubsub", "--enable-pubsub-experiment"], configPath: config.path)
        return cmd
    }

    static func ipfsTerminateDaemon(target: URL, config: URL) -> PlanetCommand {
        let cmd = PlanetCommand(command: target.path, arguments: ["shutdown"], configPath: config.path)
        return cmd
    }
}


// MARK: - PlanetCommandError
struct PlanetCommandError: Swift.Error {
    public let terminationStatus: Int32
    public var message: [String: Any] {
        return errorData.commandOutput()
    }
    public let errorData: Data
    public let outputData: Data
    public var output: [String: Any] {
        return outputData.commandOutput()
    }
}


extension PlanetCommandError: CustomStringConvertible {
    var description: String {
        return """
               PlanetCommand encountered an error
               Status code: \(terminationStatus)
               Message: "\(message)"
               Output: "\(output)"
               """
    }
}


extension PlanetCommandError: LocalizedError {
    var errorDescription: String? {
        return description
    }
}


private extension Process {
    @discardableResult func launchCommand(command: String, withArguments argus: [String], andConfigPath config: String, outputHandle: FileHandle? = nil, errorHandle: FileHandle? = nil) throws -> [String: Any] {
        executableURL = URL(fileURLWithPath: command)
        arguments = argus

        var theEnvironment = ProcessInfo.processInfo.environment
        theEnvironment["IPFS_PATH"] = PlanetManager.shared.ipfsENVPath().path
        environment = theEnvironment

        let processQueue = DispatchQueue(label: Configuration.bundlePrefix + ".planet.command-output-queue")

        var outputData = Data()
        var errorData = Data()

        let outputPipe = Pipe()
        standardOutput = outputPipe

        let errorPipe = Pipe()
        standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            processQueue.async {
                outputData.append(data)
                outputHandle?.write(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            processQueue.async {
                errorData.append(data)
                errorHandle?.write(data)
            }
        }

        launch()

        waitUntilExit()

        if let handle = outputHandle, !handle.isStandard {
            handle.closeFile()
        }

        if let handle = errorHandle, !handle.isStandard {
            handle.closeFile()
        }

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        return try processQueue.sync {
            if terminationStatus != 0 {
                throw PlanetCommandError(
                    terminationStatus: terminationStatus,
                    errorData: errorData,
                    outputData: outputData
                )
            }

            return outputData.commandOutput()
        }
    }
}


private extension FileHandle {
    var isStandard: Bool {
        return self === FileHandle.standardOutput ||
            self === FileHandle.standardError ||
            self === FileHandle.standardInput
    }
}


private extension Data {
    func commandOutput() -> [String: Any] {
        guard let output = String(data: self, encoding: .utf8) else {
            return ["result": ""]
        }
        return output.processedCommandOutput()
    }
}


private extension String {
    func processedMultilineCommandOutput() -> String {
        var s = self

        if let o = s.removingPercentEncoding {
            s = o
        }

        s = s.replacingOccurrences(of: "\t", with: " ")
        s = s.replacingOccurrences(of: "\\", with: "")

        return s
    }

    func processedCommandOutput() -> [String: Any] {
        var s = self

        if let o = s.removingPercentEncoding {
            s = o
        }

        s = s.replacingOccurrences(of: "\t", with: " ")
        s = s.replacingOccurrences(of: "\\", with: "")

        if let data = s.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                return json
            }
        }

        let o = s.components(separatedBy: "\n").filter { n in
            if n != "" {
                return true
            }
            return false
        }
        if o.count > 0 {
            return ["result": o]
        }

        return ["result": s]
    }
}
