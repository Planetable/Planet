import Foundation
import SwiftyJSON
import os

actor IPFSDaemon {
    nonisolated static let publicGateways = [
        "https://ipfs.io",
        "https://dweb.link",
        "https://cloudflare-ipfs.com",
        "https://gateway.pinata.cloud",
        "https://ipfs.fleek.co",
        "https://cf-ipfs.com",
    ]

    static let shared = IPFSDaemon()

    nonisolated let swarmPort: UInt16
    nonisolated let APIPort: UInt16
    nonisolated let gatewayPort: UInt16

    nonisolated var gateway: String {
        "http://127.0.0.1:\(gatewayPort)"
    }

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "IPFSDaemon")

    init() {
        let repoContents = try! FileManager.default.contentsOfDirectory(
            at: IPFSCommand.IPFSRepositoryPath,
            includingPropertiesForKeys: nil
        )
        if repoContents.isEmpty {
            Self.logger.info("Initializing IPFS config")
            guard let result = try? IPFSCommand.IPFSInit().run(),
                result.ret == 0
            else {
                fatalError("Error initializing IPFS")
            }
        }
        else {
            if let result = try? IPFSCommand.repoMigrate().run(),
               result.ret == 0 {
                debugPrint("IPFS repo migrated or no need to migrate at all.")
            } else {
                fatalError("Error migrating IPFS")
            }
        }

        // scout open ports
        Self.logger.info("Scouting open ports")
        if let port = IPFSDaemon.scoutPort(4001...4011),
            let result = try? IPFSCommand.updateSwarmPort(port: port).run(),
            result.ret == 0
        {
            swarmPort = port
        }
        else {
            fatalError("Unable to find open swarm port for IPFS")
        }
        if let port = IPFSDaemon.scoutPort(5981...5991),
            let result = try? IPFSCommand.updateAPIPort(port: port).run(),
            result.ret == 0
        {
            APIPort = port
        }
        else {
            fatalError("Unable to find open API port for IPFS")
        }
        if let port = IPFSDaemon.scoutPort(18181...18191),
            let result = try? IPFSCommand.updateGatewayPort(port: port).run(),
            result.ret == 0
        {
            gatewayPort = port
        }
        else {
            fatalError("Unable to find open gateway port for IPFS")
        }

        // IPFS peering
        // peers from https://docs.ipfs.io/how-to/peering-with-content-providers/#content-provider-list
        Self.logger.info("Setting peers")
        let peers = JSON([
            [
                "ID": "QmcFf2FH3CEgTNHeMRGhN7HNHU1EXAxoEk6EFuSyXCsvRE",
                "Addrs": ["/dnsaddr/node-1.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcFmLd5ySfk2WZuJ1mfSWLDjdmHZq7rSAua4GoeSQfs1z",
                "Addrs": ["/dnsaddr/node-2.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfFmzSDVbwexQ9Au2pt5YEXHK5xajwgaU6PpkbLWerMa",
                "Addrs": ["/dnsaddr/node-3.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfJeB3Js1FG7T8YaZATEiaHqNKVdQfybYYkbT1knUswx",
                "Addrs": ["/dnsaddr/node-4.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfVvzK4tMdFmpJjEKDUoqRgP4W9FnmJoziYX5GXJJ8eZ",
                "Addrs": ["/dnsaddr/node-5.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfZD3VKrUxyP9BbyUnZDpbqDnT7cQ4WjPP8TRLXaoE7G",
                "Addrs": ["/dnsaddr/node-6.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfZP2LuW4jxviTeG8fi28qjnZScACb8PEgHAc17ZEri3",
                "Addrs": ["/dnsaddr/node-7.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfgsJsMtx6qJb74akCw1M24X1zFwgGo11h1cuhwQjtJP",
                "Addrs": ["/dnsaddr/node-8.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "Qmcfr2FC7pFzJbTSDfYaSy1J8Uuy8ccGLeLyqJCKJvTHMi",
                "Addrs": ["/dnsaddr/node-9.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfR3V5YAtHBzxVACWCzXTt26SyEkxdwhGJ6875A8BuWx",
                "Addrs": ["/dnsaddr/node-10.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "Qmcfuo1TM9uUiJp6dTbm915Rf1aTqm3a3dnmCdDQLHgvL5",
                "Addrs": ["/dnsaddr/node-11.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "QmcfV2sg9zaq7UUHVCGuSvT2M2rnLBAPsiE79vVyK3Cuev",
                "Addrs": ["/dnsaddr/node-12.ingress.cloudflare-ipfs.com"],
            ],
            [
                "ID": "12D3KooWBJY6ZVV8Tk8UDDFMEqWoxn89Xc8wnpm8uBFSR3ijDkui",
                "Addrs": ["/ip4/167.71.172.216/tcp/4001", "/ip6/2604:a880:800:10::826:1/tcp/4001"],
            ],  // Pinnable
            [
                "ID": "12D3KooWLBMmT1dft1zcJvXNYkAfoUqj2RtRm7f9XkF17YmZsu4o",
                "Addrs": [
                    "/ip4/104.131.8.159/tcp/4001",
                    "/ip6/2604:a880:800:10::bc4:e001/tcp/4001",
                ],
            ],  // eth.limo
            [
                "ID": "12D3KooWMHpq3mdygcbZWbjkuDdCsX5rjZHX31uRbCp9vAZXBxcD",
                "Addrs": [
                    "/ip4/104.131.8.143/tcp/4001",
                    "/ip6/2604:a880:800:10::ac1:2001/tcp/4001",
                ],
            ],  // eth.limo
            [
                "ID": "12D3KooWQ1b2WBM1NM1a5jWS5Kny3y93zyK6iPBuVAA6uk95zdyJ",
                "Addrs": [
                    "/ip4/45.55.43.156/tcp/4001",
                    "/ip6/2604:a880:800:10::c59:6001/tcp/4001",
                ],
            ],  // eth.limo
            [
                "ID": "12D3KooWJ6MTkNM8Bu8DzNiRm1GY3Wqh8U8Pp1zRWap6xY3MvsNw",
                "Addrs": [
                    "/dnsaddr/node-1.ipfs.bit.site"
                ],
            ],  // bit.site
            [
                "ID": "12D3KooWQ85aSCFwFkByr5e3pUCQeuheVhobVxGSSs1DrRQHGv1t",
                "Addrs": [
                    "/dnsaddr/node-1.ipfs.4everland.net"
                ],
            ],  // 4everland.io
        ])
        guard
            let result = try? IPFSCommand.setPeers(
                peersJSON: String(data: peers.rawData(), encoding: .utf8)!
            ).run(),
            result.ret == 0
        else {
            fatalError("Unable to set peers for IPFS")
        }
        let swarmConnMgr = JSON(
            [
                "GracePeriod": "20s",
                "HighWater": 240,
                "LowWater": 120,
                "Type": "basic",
            ] as [String: Any]
        )
        guard
            let result = try? IPFSCommand.setSwarmConnMgr(
                String(data: swarmConnMgr.rawData(), encoding: .utf8)!
            ).run(),
            result.ret == 0
        else {
            fatalError("Unable to set parameters for Swarm Connection Manager")
        }
        let accessControlAllowOrigin = JSON(
            ["https://webui.ipfs.io"]
        )
        guard
            let result = try? IPFSCommand.setAccessControlAllowOrigin(
                String(data: accessControlAllowOrigin.rawData(), encoding: .utf8)!
            ).run(),
            result.ret == 0
        else {
            fatalError("Unable to set parameters for Access Control Allow Origin")
        }
        let accessControlAllowMethods = JSON(
            ["PUT", "POST"]
        )
        guard
            let result = try? IPFSCommand.setAccessControlAllowMethods(
                String(data: accessControlAllowMethods.rawData(), encoding: .utf8)!
            ).run(),
            result.ret == 0
        else {
            fatalError("Unable to set parameters for Access Control Allow Methods")
        }
        // update webview rule list.
        Task.detached(priority: .utility) {
            NotificationCenter.default.post(
                name: .updateRuleList,
                object: NSNumber(value: self.APIPort)
            )
        }
    }

    static func preferredGateway() -> String {
        let index: Int = UserDefaults.standard.integer(forKey: String.settingsPublicGatewayIndex)
        return IPFSDaemon.publicGateways[index]
    }

    static func urlForCID(_ cid: String) -> URL? {
        // let gateway = IPFSDaemon.preferredGateway()
        // return URL(string: gateway + "/ipfs/" + cid)
        return URL(string: "https://\(cid).ipfs2.eth.limo/")
    }

    static func urlForIPNS(_ ipns: String) -> URL? {
        // let gateway = IPFSDaemon.preferredGateway()
        // return URL(string: gateway + "/ipns/" + ipns)
        return URL(string: "https://\(ipns).ipfs2.eth.limo/")
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

    func launchDaemon() {
        Self.logger.info("Launching daemon")
        do {
            // perform a shutdown to clean possible lock file before launch daemon
            // the result of shutdown can be safely ignored
            try IPFSCommand.shutdownDaemon().run()

            try IPFSCommand.launchDaemon().run(
                outHandler: { [self] data in
                    if let output = String(data: data, encoding: .utf8),
                        output.contains("Daemon is ready")
                    {
                        Task {
                            await updateOnlineStatus()
                        }
                        // refresh published folders
                        Task.detached(priority: .utility) { @MainActor in
                            PlanetPublishedServiceStore.shared.reloadPublishedFolders()
                        }
                        // process unpublished folders
                        Task.detached(priority: .background) {
                            NotificationCenter.default.post(
                                name: .dashboardProcessUnpublishedFolders,
                                object: nil
                            )
                        }
                        // refresh key manager
                        Task.detached(priority: .utility) { @MainActor in
                            NotificationCenter.default.post(name: .keyManagerReloadUI, object: nil)
                        }

                        // let onboarding = UserDefaults.standard.string(forKey: "PlanetOnboarding")
                        // if onboarding == nil {
                        //     Task { @MainActor in
                        //         let planet = try await FollowingPlanetModel.follow(link: "vitalik.eth")
                        //         PlanetStore.shared.followingPlanets.append(planet)
                        //     }
                        //     Task { @MainActor in
                        //         let planet = try await FollowingPlanetModel.follow(link: "planetable.eth")
                        //         PlanetStore.shared.followingPlanets.append(planet)
                        //     }
                        //     UserDefaults.standard.set(Date().ISO8601Format(), forKey: "PlanetOnboarding")
                        // }
                    }
                    Self.logger.debug("[IPFS stdout]\n\(data.logFormat(), privacy: .public)")
                },
                errHandler: { data in
                    Self.logger.debug("[IPFS error]\n\(data.logFormat(), privacy: .public)")
                }
            )
        }
        catch {
            fatalError("Cannot run IPFS process")
        }
    }

    nonisolated func shutdownDaemon() {
        Self.logger.info("Shutting down daemon")
        do {
            let (ret, out, err) = try IPFSCommand.shutdownDaemon().run()
            if ret == 0 {
                Self.logger.info("Shutdown daemon returned 0")
            }
            else {
                Self.logger.error(
                    """
                    Failed to shutdown daemon: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        }
        catch {
            Self.logger.error(
                """
                Failed to shutdown daemon: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
    }

    func updateOnlineStatus() async {
        Self.logger.info("Updating online status")
        // check if management API is online
        let url = URL(string: "http://127.0.0.1:\(APIPort)/webui")!
        let request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 1
        )
        let online: Bool
        let peers: Int
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let res = response as? HTTPURLResponse, res.statusCode == 200 {
                online = true
            }
            else {
                online = false
            }
        }
        catch {
            online = false
        }
        if online {
            Task(priority: .background) {
                await PlanetStore.shared.updateServerInfo()
            }
            do {
                let data = try await IPFSDaemon.shared.api(path: "swarm/peers")
                let decoder = JSONDecoder()
                let swarmPeers = try decoder.decode(IPFSPeers.self, from: data)
                peers = swarmPeers.peers?.count ?? 0
            }
            catch {
                peers = 0
            }
        }
        else {
            peers = 0
        }
        Self.logger.info("Daemon \(online ? "online (\(peers))" : "offline", privacy: .public)")
        await MainActor.run {
            if online {
                IPFSState.shared.isBootstrapping = false
            }
            IPFSState.shared.online = online
            IPFSState.shared.peers = peers
        }
    }

    func generateKey(name: String) throws -> String {
        Self.logger.info("Generating IPFS keypair for \(name)")
        do {
            let (ret, out, err) = try IPFSCommand.generateKey(name: name).run()
            if ret == 0 {
                if let ipns = String(data: out, encoding: .utf8)?.trim() {
                    Self.logger.info("Generated IPFS keypair: id \(ipns)")
                    return ipns
                }
                Self.logger.error(
                    "Failed to parse generated IPFS keypair: \(String(describing: out))"
                )
            }
            else {
                Self.logger.error(
                    """
                    Failed to generate IPFS keypair: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        }
        catch {
            Self.logger.error(
                """
                Failed to generate IPFS keypair: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSCLIError
    }

    func removeKey(name: String) throws {
        Self.logger.info("Removing IPFS keypair for \(name)")
        do {
            let (ret, out, err) = try IPFSCommand.deleteKey(name: name).run()
            if ret == 0 {
                if let keyName = String(data: out, encoding: .utf8)?.trim() {
                    Self.logger.info("Removed IPFS keypair: id \(keyName)")
                }
                else {
                    Self.logger.error(
                        "Failed to parse removed IPFS keypair: \(String(describing: out))"
                    )
                }
            }
            else {
                Self.logger.error(
                    """
                    Failed to remove IPFS keypair: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        }
        catch {
            Self.logger.error(
                """
                Failed to remove IPFS keypair: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
    }

    func checkKeyExists(name: String) throws -> Bool {
        Self.logger.info("Check IPFS keypair exists: \(name)")
        let (ret, out, _) = try IPFSCommand.listKeys().run()
        if ret == 0 {
            if let output = String(data: out, encoding: .utf8)?.trimmingCharacters(in: .whitespaces)
            {
                let keyList = output.components(separatedBy: .newlines)
                return keyList.contains(name)
            }
            else {
                Self.logger.error("Failed to parse list IPFS keypairs: \(String(describing: out))")
            }
        }
        return false
    }

    func listKeys() throws -> [String] {
        Self.logger.info("List IPFS keypairs")
        let (ret, out, _) = try IPFSCommand.listKeys().run()
        if ret == 0 {
            if let output = String(data: out, encoding: .utf8)?.trimmingCharacters(in: .whitespaces)
            {
                return output.components(separatedBy: .newlines).filter({ $0 != "" && $0 != "self" }
                )
            }
            else {
                Self.logger.error("Failed to parse list IPFS keypairs: \(String(describing: out))")
            }
        }
        return []
    }

    func addDirectory(url: URL) throws -> String {
        Self.logger.info("Adding directory \(url.path) to IPFS")
        do {
            let (ret, out, err) = try IPFSCommand.addDirectory(directory: url).run()
            if ret == 0 {
                if let cid = String(data: out, encoding: .utf8)?.trim() {
                    Self.logger.info("Added directory \(url.path) to IPFS, CID \(cid)")
                    return cid
                }
                Self.logger.error("Failed to parse directory CID: \(String(describing: out))")
            }
            else {
                Self.logger.error(
                    """
                    Failed to add directory to IPFS: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        }
        catch {
            Self.logger.error(
                """
                Failed to add directory to IPFS: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSCLIError
    }

    nonisolated func getFileCID(url: URL) throws -> String {
        Self.logger.info("Checking file \(url.path) CID")
        do {
            let (ret, out, err) = try IPFSCommand.getFileCID(file: url).run()
            if ret == 0 {
                if let cid = String(data: out, encoding: .utf8)?.trim() {
                    Self.logger.info("File \(url.path) CID \(cid)")
                    return cid
                }
                Self.logger.error("Failed to check file CID: \(String(describing: out))")
            }
            else {
                Self.logger.error(
                    """
                    Failed to add check file CID: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        }
        catch {
            Self.logger.error(
                """
                Failed to check file CID: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSCLIError
    }

    nonisolated func getFileCIDv0(url: URL) throws -> String {
        Self.logger.info("Checking file \(url.path) CIDv0")
        do {
            let (ret, out, err) = try IPFSCommand.getFileCIDv0(file: url).run()
            if ret == 0 {
                if let cid = String(data: out, encoding: .utf8)?.trim() {
                    Self.logger.info("File \(url.path) CIDv0 \(cid)")
                    return cid
                }
                Self.logger.error("Failed to check file CIDv0: \(String(describing: out))")
            }
            else {
                Self.logger.error(
                    """
                    Failed to add check file CIDv0: process returned \(ret)
                    [stdout]
                    \(out.logFormat())
                    [stderr]
                    \(err.logFormat())
                    """
                )
            }
        }
        catch {
            Self.logger.error(
                """
                Failed to check file CIDv0: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSCLIError
    }

    func resolveIPNSorDNSLink(name: String) async throws -> String {
        Self.logger.info("Resolving IPNS or DNSLink \(name)")
        do {
            let resolved: IPFSResolved
            let result = try await api(path: "name/resolve", args: ["arg": name])
            do {
                resolved = try JSONDecoder.shared.decode(IPFSResolved.self, from: result)
            }
            catch {
                Self.logger.error(
                    """
                    Failed to resolve IPNS or DNSLink \(name): got error from API call, \
                    error: \(result.logFormat())
                    """
                )
                throw IPFSDaemonError.IPFSAPIError
            }
            let cidWithPrefix = resolved.path
            if cidWithPrefix.starts(with: "/ipfs/") {
                return String(cidWithPrefix.dropFirst("/ipfs/".count))
            }
            Self.logger.error(
                """
                Failed to resolve IPNS or DNSLink \(name): unknown result from API call, \
                got \(result.logFormat())
                """
            )
        }
        catch {
            Self.logger.error(
                """
                Failed to resolve IPNS or DNSLink \(name): error when accessing IPFS API, \
                cause: \(String(describing: error))
                """
            )
        }
        throw IPFSDaemonError.IPFSAPIError
    }

    func pin(cid: String) async throws {
        Self.logger.info("Pinning \(cid)")
        try await IPFSDaemon.shared.api(path: "pin/add", args: ["arg": cid], timeout: 120)
    }

    func unpin(cid: String) async throws {
        Self.logger.info("Unpinning \(cid)")
        try await IPFSDaemon.shared.api(path: "pin/rm", args: ["arg": cid], timeout: 120)
    }

    func getFile(ipns: String, path: String = "") async throws -> Data {
        Self.logger.info("Getting file from IPNS \(ipns)\(path)")
        let url = URL(string: "\(gateway)/ipns/\(ipns)\(path)")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let httpResponse = response as! HTTPURLResponse
        if !httpResponse.ok {
            Self.logger.error(
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
        timeout: TimeInterval = 30
    ) async throws -> Data {
        var url: URL = URL(string: "http://127.0.0.1:\(APIPort)/api/v0/\(path)")!
        if !args.isEmpty {
            url = url.appendingQueryParameters(args)
        }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.ok
        else {
            throw IPFSDaemonError.IPFSAPIError
        }
        // debugPrint the response
        if let responseString = String(data: data, encoding: .utf8) {
            if path == "swarm/peers" {
                let decoder = JSONDecoder()
                var peers = 0
                if let swarmPeers = try? decoder.decode(IPFSPeers.self, from: data) {
                    peers = swarmPeers.peers?.count ?? 0
                    debugPrint("IPFS API Response for \(path): \(peers) peers")
                }
            }
            else {
                debugPrint("IPFS API Response for \(path) / \(args): \(responseString)")
            }

        }
        return data
    }
}

enum IPFSDaemonError: Error {
    case IPFSCLIError
    case IPFSAPIError
}

enum IPFSGateway: String, Codable, CaseIterable {
    case limo
    case sucks
    case croptop
    case cloudflare
    case dweblink

    static let names: [String: String] = [
        "limo": "eth.limo",
        "sucks": "eth.sucks",
        "croptop": "Croptop",
        "cloudflare": "Cloudflare",
        "dweblink": "DWeb.link",
    ]

    var name: String {
        IPFSGateway.names[rawValue] ?? rawValue
    }

    static let websites: [String: String] = [
        "limo": "https://eth.limo",
        "sucks": "https://eth.sucks",
        "croptop": "https://crop.top",
        "cloudflare": "https://cf-ipfs.com",
        "dweblink": "https://dweb.link",
    ]

    static let defaultGateway: IPFSGateway = .limo

    static func selectedGateway() -> IPFSGateway {
        let gateway = UserDefaults.standard.string(forKey: String.settingsPreferredIPFSPublicGateway)
        return IPFSGateway(rawValue: gateway ?? IPFSGateway.defaultGateway.rawValue) ?? IPFSGateway.defaultGateway
    }
}
