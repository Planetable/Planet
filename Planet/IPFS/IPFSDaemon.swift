import Foundation
import SwiftyJSON
import UserNotifications
import os

actor IPFSDaemon {
    static let shared = IPFSDaemon()

    private var settingUp: Bool = false
    private var swarmPort: UInt16!
    private var apiPort: UInt16!
    private var gatewayPort: UInt16!

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "IPFSDaemon")

    init() {
        Self.logger.info("IPFS Daemon Init")
    }

    func setupIPFS(andLaunch launch: Bool = false) async {
        guard !settingUp else { return }
        settingUp = true
        defer {
            settingUp = false
        }

        Self.logger.info("Setting up IPFS")

        let repoContents = try! FileManager.default.contentsOfDirectory(
            at: IPFSCommand.IPFSRepositoryPath,
            includingPropertiesForKeys: nil
        )
        if repoContents.isEmpty {
            Self.logger.info("Initializing IPFS config")
            if let result = try? IPFSCommand.IPFSInit().run(),
                result.ret == 0
            {
                Self.logger.info("IPFS Initialized")
            }
            else {
                Self.logger.info("Error Initializing IPFS")
                return
            }
        }

        Self.logger.info(
            "Verifying IPFS repo version\nAt path: \(IPFSCommand.IPFSRepositoryPath)\nVia exe: \(IPFSCommand.IPFSExecutablePath)"
        )

        /*  Skip IPFS migration process
        do {
            // Read current repo version on disk
            let repoVersion = try await IPFSMigrationCommand.currentRepoVersion()
            Self.logger.info("Current IPFS repo version on disk: \(repoVersion)")
            let expectedVersion = IPFSCommand.IPFSRepoVersion
            Self.logger.info("Expected IPFS repo version: \(expectedVersion)")
            let migrationRepoNames = IPFSMigrationCommand.migrationRepoNames(
                forRepoVersion: repoVersion
            )
            if repoVersion < expectedVersion && migrationRepoNames.count > 0 {
                Self.logger.info(
                    "Current IPFS repo version \(repoVersion) is lower than app runtime repo version \(expectedVersion), prepare migration..."
                )
                for name in migrationRepoNames {
                    Self.logger.info("Migrating \(name)")
                    let command = IPFSMigrationCommand(repoName: name)
                    let data = try await command.run()
                    Self.logger.info("Response from IPFS repo version migration \(name): \(data.logFormat())")
                }
            }
            else if repoVersion > expectedVersion {
                Self.logger.info(
                    "⚠️ Current IPFS repo version \(repoVersion) on disk is higher than app runtime repo version \(expectedVersion), IPFS will not start and will tell the user to update the app."
                )
                await MainActor.run {
                    IPFSState.shared.reasonIPFSNotRunning = "IPFS repo version \(repoVersion) on disk is higher than app runtime repo version \(expectedVersion), please update the app."
                }
                return
            }
            else {
                Self.logger.info("✅ IPFS repo version verified: \(repoVersion), no need to migrate.")
            }
        }
        catch {
            Self.logger.info("Error Verifying Repo Version: \(error)")
            await MainActor.run {
                IPFSState.shared.reasonIPFSNotRunning = "An error occurred while verifying IPFS repo version. Please try again or update the app.\n\nError: \(error)"
            }
            return
        }
         */

        Self.logger.info("Updating swarm port")
        if let port = IPFSDaemon.scoutPort(4001...4011),
            let result = try? IPFSCommand.updateSwarmPort(port: port).run(),
            result.ret == 0
        {
            swarmPort = port
            await MainActor.run {
                IPFSState.shared.updateSwarmPort(port)
            }
            Self.logger.info("Updated swarm port: \(port)")
        }
        else {
            Self.logger.info("Unable to find open swarm port for IPFS")
            return
        }

        Self.logger.info("Updating API port")
        if let port = IPFSDaemon.scoutPort(5981...5991),
            let result = try? IPFSCommand.updateAPIPort(port: port).run(),
            result.ret == 0
        {
            apiPort = port
            await MainActor.run {
                IPFSState.shared.updateAPIPort(port)
            }
            Self.logger.info("Updated API port: \(port)")
        }
        else {
            Self.logger.info("Unable to find open API port for IPFS")
            return
        }

        Self.logger.info("Updating gateway port")
        if let port = IPFSDaemon.scoutPort(18181...18191),
            let result = try? IPFSCommand.updateGatewayPort(port: port).run(),
            result.ret == 0
        {
            gatewayPort = port
            await MainActor.run {
                IPFSState.shared.updateGatewayPort(port)
            }
            Self.logger.info("Updated gateway port: \(port)")
        }
        else {
            Self.logger.info("Unable to find open gateway port for IPFS")
            return
        }

        /*  Skip IPFS migration process
        // Set IPNS options
        Self.logger.info("Setting IPNS options")

        // Ipns.MaxCacheTTL (needed starting from 0.28.0)
        if let result = try? IPFSCommand.setIPNSMaxCacheTTL().run() {
            if result.ret == 0 {
                Self.logger.info("Set Ipns.MaxCacheTTL")
            }
            else {
                if let errorString = String(data: result.err, encoding: .utf8) {
                    Self.logger.info(
                        "Failed to set Ipns.MaxCacheTTL: \(errorString, privacy: .public)"
                    )
                }
                else {
                    Self.logger.info("Failed to set Ipns.MaxCacheTTL: (unknown error)")
                }
            }
        }
        else {
            Self.logger.info("Unable to set Ipns.MaxCacheTTL")
        }

        // Ipns.UsePubsub (needed starting from 0.28.0)
        if let result = try? IPFSCommand.setIPNSUsePubsub().run() {
            if result.ret == 0 {
                Self.logger.info("Set Ipns.UsePubsub")
            }
            else {
                if let errorString = String(data: result.err, encoding: .utf8) {
                    Self.logger.info(
                        "Failed to set Ipns.UsePubsub: \(errorString, privacy: .public)"
                    )
                }
                else {
                    Self.logger.info("Failed to set Ipns.UsePubsub: (unknown error)")
                }
            }
        }
        else {
            Self.logger.info("Unable to set Ipns.UsePubsub")
        }

        // Gateway.HTTPHeaders (needed starting from 0.28.0)
        if let result = try? IPFSCommand.setGatewayHeaders().run() {
            if result.ret == 0 {
                Self.logger.info("Set Gateway.HTTPHeaders")
            }
            else {
                if let errorString = String(data: result.err, encoding: .utf8) {
                    Self.logger.info(
                        "Failed to set Gateway.HTTPHeaders: \(errorString, privacy: .public)"
                    )
                }
                else {
                    Self.logger.info("Failed to set Gateway.HTTPHeaders: (unknown error)")
                }
            }
        }
        else {
            Self.logger.info("Unable to set Gateway.HTTPHeaders")
        }
         */

        Self.logger.info("Updating peers")
        if let result = try? IPFSCommand.setPeers(
            peersJSON: String(data: IPFSDaemon.peers.rawData(), encoding: .utf8)!
        ).run(),
            result.ret == 0
        {
            Self.logger.info("Updated peers")
        }
        else {
            Self.logger.info("Unable to set peers for IPFS")
        }

        Self.logger.info("Set DNS resolvers")
        if let result = try? IPFSCommand.setResolvers(
            resolversJSON: String(data: IPFSDaemon.resolvers.rawData(), encoding: .utf8)!
        ).run(),
            result.ret == 0
        {
            Self.logger.info("Set DNS resolvers")
        }
        else {
            Self.logger.info("Unable to set DNS resolvers")
        }

        let swarmConnMgr = JSON(
            [
                "GracePeriod": "20s",
                "HighWater": 240,
                "LowWater": 120,
                "Type": "basic",
            ] as [String: Any]
        )
        Self.logger.info("Updating parameters for Swarm Connection Manager")
        if let result = try? IPFSCommand.setSwarmConnMgr(
            String(data: swarmConnMgr.rawData(), encoding: .utf8)!
        ).run(),
            result.ret == 0
        {
            Self.logger.info("Updated parameters for Swarm Connection Manager")
        }
        else {
            Self.logger.info("Unable to set parameters for Swarm Connection Manager")
            return
        }

        let accessControlAllowOrigin = JSON(
            ["https://webui.ipfs.io"]
        )
        Self.logger.info("Updating parameters for Access Control Allow Origin")
        if let result = try? IPFSCommand.setAccessControlAllowOrigin(
            String(data: accessControlAllowOrigin.rawData(), encoding: .utf8)!
        ).run(),
            result.ret == 0
        {
            Self.logger.info("Updated parameters for Access Control Allow Origin")
        }
        else {
            Self.logger.info("Unable to set parameters for Access Control Allow Origin")
            return
        }

        let accessControlAllowMethods = JSON(
            ["PUT", "POST"]
        )
        Self.logger.info("Updating parameters for Access Control Allow Methods")
        if let result = try? IPFSCommand.setAccessControlAllowMethods(
            String(data: accessControlAllowMethods.rawData(), encoding: .utf8)!
        ).run(),
            result.ret == 0
        {
            Self.logger.info("Updated parameters for Access Control Allow Methods")
        }
        else {
            Self.logger.info("Unable to set parameters for Access Control Allow Methods")
        }

        Self.logger.info("IPFS Setup Completed")

        if launch {
            try? self.launch()
        }
    }

    func launch() throws {
        Self.logger.info("Launching daemon")
        if swarmPort == nil || apiPort == nil || gatewayPort == nil {
            Self.logger.info("IPFS is not ready, abort launching process, trying to setup again.")
            Task.detached(priority: .utility) {
                await self.setupIPFS(andLaunch: true)
            }
            throw PlanetError.IPFSError
        }
        _ = try? IPFSCommand.shutdownDaemon().run()
        do {
            Task { @MainActor in
                IPFSState.shared.updateOperatingStatus(true)
            }
            try IPFSCommand.launchDaemon().run(
                outHandler: { data in
                    let log = data.logFormat()
                    Self.logger.debug("[IPFS stdout]\n\(log, privacy: .public)")
                    if log.contains("Daemon is ready") {
                        Self.logger.info("Daemon launched")
                        Task.detached(priority: .utility) {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            await IPFSState.shared.updateStatus()
                            IPFSState.shared.updateAppSettings()
                            try? await IPFSState.shared.calculateRepoSize()
                            Task { @MainActor in
                                IPFSState.shared.updateOperatingStatus(false)
                            }
                        }
                    }
                },
                errHandler: { data in
                    let log = data.logFormat()
                    Self.logger.debug("[IPFS error]\n\(log, privacy: .public)")
                    Task { @MainActor in
                        IPFSState.shared.updateOperatingStatus(false)
                    }
                }
            )
        }
        catch {
            Self.logger.error(
                """
                Failed to launch daemon: error when running IPFS process, \
                cause: \(String(describing: error))
                """
            )
            Self.logger.info("Failed to launch daemon: \(String(describing: error))")
            Task { @MainActor in
                IPFSState.shared.updateOperatingStatus(false)
            }
            throw PlanetError.IPFSError
        }
    }

    func shutdown() throws {
        Self.logger.info("Shutting down daemon")
        Task { @MainActor in
            IPFSState.shared.updateOperatingStatus(true)
        }
        do {
            let (ret, out, err) = try IPFSCommand.shutdownDaemon().run()
            if ret == 0 {
                Self.logger.info("Daemon shut down")
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
        Task { @MainActor in
            IPFSState.shared.updateOperatingStatus(false)
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
        throw PlanetError.IPFSError
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
        throw PlanetError.IPFSError
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
        throw PlanetError.IPFSError
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
        throw PlanetError.IPFSError
    }

    func getStatsBW() async throws -> IPFSBandwidth {
        Self.logger.info("Getting IPFS bandwidth stats")
        do {
            let result = try await api(path: "stats/bw")
            do {
                return try JSONDecoder.shared.decode(IPFSBandwidth.self, from: result)
            }
            catch {
                Self.logger.error(
                    """
                    Failed to get IPFS bandwidth stats: got error from API call, \
                    result: \(result.logFormat()) \
                    error: \(String(describing: error))
                    """
                )
                throw PlanetError.IPFSAPIError
            }
        }
        catch {
            Self.logger.error(
                """
                Failed to get IPFS bandwidth stats: error when accessing IPFS API, \
                cause: \(String(describing: error))
                """
            )
        }
        throw PlanetError.IPFSAPIError
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
                throw PlanetError.IPFSAPIError
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
        throw PlanetError.IPFSAPIError
    }

    func pin(cid: String) async throws {
        Self.logger.info("Pinning \(cid)")
        try await IPFSDaemon.shared.api(path: "pin/add", args: ["arg": cid], timeout: 120)
    }

    func unpin(cid: String) async throws {
        Self.logger.info("Unpinning \(cid)")
        try await IPFSDaemon.shared.api(path: "pin/rm", args: ["arg": cid], timeout: 120)
    }

    func gc() async throws {
        Self.logger.info("Running garbage collection")
        let result = try await IPFSDaemon.shared.api(path: "repo/gc", timeout: 120)
        // Parse JSON result array
        let count = String(data: result, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { $0.contains("Key") }
            .count ?? 0

        if count > 0 {
            // Create and schedule notification
            let content = UNMutableNotificationContent()
            content.title = "IPFS Garbage Collection Complete"
            content.body = "Removed \(count) unused objects"
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            try? await UNUserNotificationCenter.current().add(request)
            Self.logger.info("Garbage collection removed \(count) objects")
        } else {
            Self.logger.info("Garbage collection did not remove any objects")
        }
    }

    func getFile(ipns: String, path: String = "") async throws -> Data {
        Self.logger.info("Getting file from IPNS \(ipns)\(path)")
        guard let gatewayPort else {
            throw PlanetError.IPFSError
        }
        let gateway = IPFSState.shared.getGateway()
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
            throw PlanetError.IPFSAPIError
        }
        return data
    }

    @discardableResult func api(
        path: String,
        args: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> Data {
        guard let apiPort else {
            throw PlanetError.IPFSError
        }
        var url: URL = URL(string: "http://127.0.0.1:\(apiPort)/api/v0/\(path)")!
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
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.ok
        else {
            if let errorDetails = String(data: data, encoding: .utf8) {
                debugPrint("Failed to access IPFS API \(path): \(errorDetails)")
            }
            debugPrint("IPFS API Error: \(response)")
            throw PlanetError.IPFSAPIError
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

extension IPFSDaemon {
    // IPFS peering
    // peers from https://docs.ipfs.io/how-to/peering-with-content-providers/#content-provider-list
    static let peers = JSON([
        [
            "ID": "12D3KooWBJY6ZVV8Tk8UDDFMEqWoxn89Xc8wnpm8uBFSR3ijDkui",
            "Addrs": [
                "/ip4/167.71.172.216/tcp/4001",
                "/ip6/2604:a880:800:10::826:1/tcp/4001",
                "/ip4/167.71.172.216/udp/4001/quic",
                "/ip6/2604:a880:800:10::826:1/udp/4001/quic"
            ],
        ],  // Pinnable
        [
            "ID": "12D3KooWDaGQ3Fu3iLgFxrrg5Vfef9z5L3DQZoyqFxQJbKKPnCc8",
            "Addrs": [
                "/ip4/143.198.18.166/tcp/4001",
                "/ip6/2604:a880:800:10::735:7001/tcp/4001",
                "/ip4/143.198.18.166/udp/4001/quic",
                "/ip6/2604:a880:800:10::735:7001/udp/4001/quic"
            ],
        ],  // eth.sucks
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
        [
            "ID": "12D3KooWGtYkBAaqJMJEmywMxaCiNP7LCEFUAFiLEBASe232c2VH",
            "Addrs": [
                "/dns4/bitswap.filebase.io/tcp/443/wss"
            ],
        ]   // Filebase
    ])
    // DoH resolvers
    static let resolvers = JSON([
        "bit.": "https://dweb-dns.v2ex.pro/dns-query",
        "sol.": "https://dweb-dns.v2ex.pro/dns-query",
        "eth.": "https://dns.eth.limo/dns-query"
    ])

    static func urlForCID(_ cid: String) -> URL? {
        return URL(string: "https://\(cid).eth.sucks/")
    }

    static func urlForIPNS(_ ipns: String) -> URL? {
        return URL(string: "https://\(ipns).eth.sucks/")
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
}
