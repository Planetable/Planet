import Foundation
import os

@globalActor actor IPFSActor {
    static let shared: IPFSActor = .init()
}

class IPFSDaemon {
    private static var _shared: IPFSDaemon? = nil
    static var shared: IPFSDaemon {
        get async {
            if _shared == nil {
                _shared = await .init()
            }
            return _shared!
        }
    }

    let swarmPort: UInt16
    let APIPort: UInt16
    let gatewayPort: UInt16

    var gateway: String {
        "http://127.0.0.1:\(gatewayPort)"
    }

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "IPFSDaemon")

    @IPFSActor init() {
        let repoContents = try! FileManager.default.contentsOfDirectory(
            at: IPFSCommand.IPFSRepositoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        if repoContents.isEmpty {
            logger.info("Initializing IPFS config")
            guard let result = try? IPFSCommand.IPFSInit().run(),
                  result.ret == 0 else {
                fatalError("Error initializing IPFS")
            }
        } else {
            // check IPFS repo version
            let versionFileURL = IPFSCommand.IPFSRepositoryURL.appendingPathComponent("version", isDirectory: false)
            do {
                let versionString = (try String(contentsOf: versionFileURL)).trim()
                guard let version = Int(versionString) else {
                    fatalError("Cannot check IPFS repository version")
                }
                if version != IPFSMigration.repoVersion {
                    logger.info("Migrating local IPFS repo from version \(version) to version \(IPFSMigration.repoVersion)")
                    do {
                        let (ret, out, err) = try IPFSMigration.migrate()
                        if ret == 0 {
                            logger.info("Migrated local IPFS repo to version \(IPFSMigration.repoVersion)")
                        } else {
                            logger.error(
                                """
                                Failed to migrate local IPFS repo from version \(version) to version \(IPFSMigration.repoVersion): process returned \(ret)
                                [stdout]
                                \(out.logFormat())
                                [stderr]
                                \(err.logFormat())
                                """
                            )
                        }
                    } catch {
                        fatalError(
                            """
                            Cannot migrate local IPFS repo from version \(version) to version \(IPFSMigration.repoVersion), \
                            cause: \(error)
                            """
                        )
                    }
                }
            } catch {
                // IPFS repo version file is missing and the repo is likely corrupted
                fatalError("Cannot check IPFS repository version")
            }
        }

        // scout open ports
        logger.info("Scouting open ports")
        if let port = IPFSDaemon.scoutPort(4001...4011),
           let result = try? IPFSCommand.updateSwarmPort(port: port).run(),
           result.ret == 0 {
            swarmPort = port
        } else {
            fatalError("Unable to find open swarm port for IPFS")
        }
        if let port = IPFSDaemon.scoutPort(5981...5991),
           let result = try? IPFSCommand.updateAPIPort(port: port).run(),
           result.ret == 0 {
            APIPort = port
        } else {
            fatalError("Unable to find open API port for IPFS")
        }
        if let port = IPFSDaemon.scoutPort(18181...18191),
           let result = try? IPFSCommand.updateGatewayPort(port: port).run(),
           result.ret == 0 {
            gatewayPort = port
        } else {
            fatalError("Unable to find open gateway port for IPFS")
        }

        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [self] timer in
            Task.init {
                await updateOnlineStatus()
                if !(await IPFSState.shared.online) {
                    launchDaemon()
                }
            }
        }
    }

    // Reference: https://stackoverflow.com/a/65162953
    static func isPortOpen(port: in_port_t) -> Bool {
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return false
        }

        var addr = sockaddr_in()
        let sizeOfSocketAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSocketAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSocketAddr))

        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSocketAddr)) == -1 {
            return false
        }
        let isOpen = listen(socketFileDescriptor, SOMAXCONN) != -1
        Darwin.close(socketFileDescriptor)
        return isOpen
    }

    static func scoutPort(_ range: ClosedRange<UInt16>) -> UInt16? {
        for port in range {
            if isPortOpen(port: port) {
                return port
            }
        }
        return nil
    }

    @IPFSActor func launchDaemon() {
        logger.info("Launching daemon")
        do {
            // perform a shutdown to clean possible lock file before launch daemon
            // the result of shutdown can be safely discarded
            try IPFSCommand.shutdownDaemon().run()

            try IPFSCommand.launchDaemon().run(
                outHandler: { [self] data in
                    logger.debug("[IPFS stdout]\n\(data.logFormat())")
                },
                errHandler: { [self] data in
                    logger.debug("[IPFS error]\n\(data.logFormat())")
                }
            )
        } catch {
            fatalError("Cannot run IPFS process")
        }

        Task.init {
            try await Task.sleep(seconds: 10)
            await updateOnlineStatus()
        }
    }

    @IPFSActor func shutdownDaemon() {
        logger.info("Shutting down daemon")
        do {
            let (ret, out, err) = try IPFSCommand.shutdownDaemon().run()
            if ret == 0 {
                logger.info("Shutdown daemon returned 0")
            } else {
                logger.error(
                    """
                    Failed to shutdown daemon: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        } catch {
            logger.error(
                """
                Failed to shutdown daemon: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
    }

    func updateOnlineStatus() async {
        logger.info("Updating online status")
        // check if management API is online
        let url = URL(string: "http://127.0.0.1:\(APIPort)/webui")!
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1)
        let online: Bool
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let res = response as? HTTPURLResponse, res.statusCode == 200 {
                online = true
            } else {
                online = false
            }
        } catch {
            online = false
        }
        logger.info("Daemon \(online ? "online" : "offline")")
        await MainActor.run {
            IPFSState.shared.online = online
        }
    }

    @IPFSActor func generateKey(name: String) throws -> String {
        logger.info("Generating IPFS keypair for \(name)")
        do {
            let (ret, out, err) = try IPFSCommand.generateKey(name: name).run()
            if ret == 0 {
                if let ipns = String(data: out, encoding: .utf8)?.trim() {
                    logger.info("Generated IPFS keypair: id \(ipns)")
                    return ipns
                }
                logger.error("Failed to parse generated IPFS keypair: \(String(describing: out))")
            } else {
                logger.error(
                    """
                    Failed to generate IPFS keypair: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        } catch {
            logger.error(
                """
                Failed to generate IPFS keypair: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError()
    }

    @IPFSActor func addDirectory(url: URL) throws -> String {
        logger.info("Adding directory \(url.path) to IPFS")
        do {
            let (ret, out, err) = try IPFSCommand.addDirectory(directory: url).run()
            if ret == 0 {
                if let cid = String(data: out, encoding: .utf8)?.trim() {
                    logger.info("Added directory \(url.path) to IPFS, CID \(cid)")
                    return cid
                }
                logger.error("Failed to parse directory CID: \(String(describing: out))")
            } else {
                logger.error(
                    """
                    Failed to add directory to IPFS: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        } catch {
            logger.error(
                """
                Failed to add directory to IPFS: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError()
    }

    @IPFSActor func getFileCID(url: URL) throws -> String {
        logger.info("Checking file \(url.path) CID")
        do {
            let (ret, out, err) = try IPFSCommand.getFileCID(file: url).run()
            if ret == 0 {
                if let cid = String(data: out, encoding: .utf8)?.trim() {
                    logger.info("File \(url.path) CID \(cid)")
                    return cid
                }
                logger.error("Failed to check file CID: \(String(describing: out))")
            } else {
                logger.error(
                    """
                    Failed to add check file CID: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        } catch {
            logger.error(
                """
                Failed to check file CID: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError()
    }

    @IPFSActor func publish(key: String, cid: String) throws {
        logger.info("Publishing \(cid) for \(key)")
        do {
            let (ret, out, err) = try IPFSCommand.publish(key: key, cid: cid).run()
            if ret == 0 {
                logger.info("Published \(cid) for \(key)")
                logger.debug("[stdout]\n\(out.logFormat())")
                return
            } else {
                logger.error(
                    """
                    Failed to publish \(cid) for \(key): process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        } catch {
            logger.error(
                """
                Failed to publish \(cid) for \(key): error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError()
    }

    @IPFSActor func resolveIPNS(ipns: String) throws -> String {
        logger.info("Resolving IPNS \(ipns)")
        do {
            let (ret, out, err) = try IPFSCommand.resolveIPNS(ipns: ipns).run()
            if ret == 0 {
                if let cid = String(data: out, encoding: .utf8)?.trim() {
                    logger.info("Resolved IPNS \(ipns) to CID \(cid)")
                    return cid
                }
                logger.error("Failed to resolve IPNS \(ipns): \(String(describing: out))")
            } else {
                logger.error(
                    """
                    Failed to resolve IPNS \(ipns): process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        } catch {
            logger.error(
                    """
                    Failed to resolve IPNS \(ipns): error when running IPFS process, \
                    cause: \(String(describing: error))
                    """
            )
        }
        throw IPFSDaemonError()
    }

    func getFile(ipns: String, path: String = "") async throws -> Data {
        logger.info("Getting file from IPNS \(ipns)\(path)")
        let url = URL(string: "\(gateway)/ipns/\(ipns)\(path)")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let httpResponse = response as! HTTPURLResponse
        if !httpResponse.ok {
            logger.error(
                """
                Failed to get file from IPFS \(ipns)\(path): HTTP status \(httpResponse.statusCode)
                [HTTP response body]
                \(data.logFormat())
                """
            )
        }
        return data
    }
}

struct IPFSDaemonError: Error {
}
