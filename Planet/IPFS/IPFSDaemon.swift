import Foundation
import os
import SwiftyJSON

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

        // add peering
        // peers from https://docs.ipfs.io/how-to/peering-with-content-providers/#content-provider-list
        // adding Cloudflare and ProtocolLabs
        // last updated: 2022-05-09
        logger.info("Setting peers")
        let peers = JSON([
            ["ID": "12D3KooWBJY6ZVV8Tk8UDDFMEqWoxn89Xc8wnpm8uBFSR3ijDkui", "Addrs": ["/ip4/167.71.172.216/tcp/4001", "/ip6/2604:a880:800:10::826:1/tcp/4001"]],
            ["ID": "QmcfgsJsMtx6qJb74akCw1M24X1zFwgGo11h1cuhwQjtJP", "Addrs": ["/ip6/2606:4700:60::6/tcp/4009", "/ip4/172.65.0.13/tcp/4009"]],
            ["ID": "QmUEMvxS2e7iDrereVYc5SWPauXPyNwxcy9BXZrC1QTcHE", "Addrs": ["/dns/cluster0.fsn.dwebops.pub"]],
            ["ID": "QmNSYxZAiJHeLdkBg38roksAR9So7Y5eojks1yjEcUtZ7i", "Addrs": ["/dns/cluster1.fsn.dwebops.pub"]],
            ["ID": "QmUd6zHcbkbcs7SMxwLs48qZVX3vpcM8errYS7xEczwRMA", "Addrs": ["/dns/cluster2.fsn.dwebops.pub"]],
            ["ID": "QmbVWZQhCGrS7DhgLqWbgvdmKN7JueKCREVanfnVpgyq8x", "Addrs": ["/dns/cluster3.fsn.dwebops.pub"]],
            ["ID": "QmdnXwLrC8p1ueiq2Qya8joNvk3TVVDAut7PrikmZwubtR", "Addrs": ["/dns/cluster4.fsn.dwebops.pub"]],
            ["ID": "12D3KooWCRscMgHgEo3ojm8ovzheydpvTEqsDtq7Vby38cMHrYjt", "Addrs": ["/dns4/nft-storage-am6.nft.dwebops.net/tcp/18402"]],
            ["ID": "12D3KooWQtpvNvUYFzAo1cRYkydgk15JrMSHp6B6oujqgYSnvsVm", "Addrs": ["/dns4/nft-storage-dc13.nft.dwebops.net/tcp/18402"]],
            ["ID": "12D3KooWQcgCwNCTYkyLXXQSZuL5ry1TzpM8PRe9dKddfsk1BxXZ", "Addrs": ["/dns4/nft-storage-sv15.nft.dwebops.net/tcp/18402"]],
        ])
        guard let result = try? IPFSCommand.setPeers(peersJSON: String(data: peers.rawData(), encoding: .utf8)!).run(),
              result.ret == 0
        else {
            fatalError("Unable to set peers for IPFS")
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
            // the result of shutdown can be safely ignored
            try IPFSCommand.shutdownDaemon().run()

            try IPFSCommand.launchDaemon().run(
                outHandler: { [self] data in
                    if let output = String(data: data, encoding: .utf8),
                       output.contains("Daemon is ready") {
                        Task {
                            await updateOnlineStatus()
                        }
                        let onboarding = UserDefaults.standard.string(forKey: "PlanetOnboarding")
                        if onboarding == nil {
                            Task {
                                let planet = PlanetDataController.shared.createPlanet(ens: "vitalik.eth")!
                                try await PlanetManager.shared.update(planet)
                            }
                            Task {
                                let planet = PlanetDataController.shared.createPlanet(ens: "planetable.eth")!
                                try await PlanetManager.shared.update(planet)
                            }
                            UserDefaults.standard.set(Date().ISO8601Format(), forKey: "PlanetOnboarding")
                        }
                    }
                    logger.debug("[IPFS stdout]\n\(data.logFormat())")
                },
                errHandler: { [self] data in
                    logger.debug("[IPFS error]\n\(data.logFormat())")
                }
            )
        } catch {
            fatalError("Cannot run IPFS process")
        }
    }

    func shutdownDaemon() {
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
        let peers: Int
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
        if online {
            do {
                let data = try await IPFSDaemon.shared.api(path: "swarm/peers")
                let decoder = JSONDecoder()
                let swarmPeers = try decoder.decode(PlanetPeers.self, from: data)
                peers = swarmPeers.peers?.count ?? 0
            } catch {
                peers = 0
            }
        } else {
            peers = 0
        }
        logger.info("Daemon \(online ? "online (\(peers))" : "offline")")
        await MainActor.run {
            IPFSState.shared.online = online
            IPFSState.shared.peers = peers
        }
    }

    func generateKey(name: String) throws -> String {
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
        throw IPFSDaemonError.IPFSCLIError
    }

    func addDirectory(url: URL) throws -> String {
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
        throw IPFSDaemonError.IPFSCLIError
    }

    func getFileCID(url: URL) throws -> String {
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
        throw IPFSDaemonError.IPFSCLIError
    }

    func publish(key: String, cid: String) throws {
        logger.info("Publishing \(cid) for \(key)")
        do {
            let (ret, out, err) = try IPFSCommand.publish(key: key, cid: cid).run()
            if ret == 0 {
                logger.info("Published \(cid) for \(key)")
                logger.debug("[stdout]\n\(out.logFormat())")
                return
            }
            logger.error(
                """
                Failed to publish \(cid) for \(key): process returned \(ret)
                [stdout]
                \(out.logFormat())
                [stderr]
                \(err.logFormat())
                """
            )
        } catch {
            logger.error(
                """
                Failed to publish \(cid) for \(key): error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSCLIError
    }

    func resolveIPNS(ipns: String) throws -> String {
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
        throw IPFSDaemonError.IPFSCLIError
    }

    func pin(cid: String) async throws {
        logger.info("Pinning \(cid)")
        do {
            let (ret, out, err) = try IPFSCommand.pin(cid: cid).run()
            if ret == 0 {
                logger.info("Pinned \(cid)")
                return
            }
            logger.error(
                """
                Failed to pin \(cid): process returned \(ret)
                [stdout]
                \(out.logFormat())
                [stderr]
                \(err.logFormat())
                """
            )
        } catch {
            logger.error(
                """
                Failed to pin \(cid): error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSCLIError
    }

    func pin(ipns: String) throws {
        logger.info("Pinning IPNS \(ipns)")
        do {
            let (ret, out, err) = try IPFSCommand.pin(ipns: ipns).run()
            if ret == 0 {
                logger.info("Pinned IPNS \(ipns)")
                return
            }
            logger.error(
                """
                Failed to pin IPNS \(ipns): process returned \(ret)
                [stdout]
                \(out.logFormat())
                [stderr]
                \(err.logFormat())
                """
            )
        } catch {
            logger.error(
                """
                Failed to pin IPNS \(ipns): error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSCLIError
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

    @discardableResult func api(
            path: String,
            args: [String: String] = [:],
            timeout: TimeInterval = 5
    ) async throws -> Data {
        var url: URL = URL(string: "http://127.0.0.1:\(APIPort)/api/v0/\(path)")!
        if !args.isEmpty {
            url = url.appendingQueryParameters(args)
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok
        else {
            throw IPFSDaemonError.IPFSAPIError
        }
        return data
    }
}

enum IPFSDaemonError: Error {
    case IPFSCLIError
    case IPFSAPIError
}
