import Foundation
import os


class IPFSState: ObservableObject {
    static let shared = IPFSState()

    static let refreshRate: TimeInterval = 20
    static let lastUserLaunchState: String = "PlanetIPFSLastUserLaunchStateKey"

    @Published var isShowingStatus = false

    @Published private(set) var isOperating = false
    @Published private(set) var online = false
    @Published private(set) var apiPort: UInt16 = 5981
    @Published private(set) var gatewayPort: UInt16 = 18181
    @Published private(set) var swarmPort: UInt16 = 4001

    init() {
        debugPrint("IPFS State Manager Init")
        Task(priority: .userInitiated) {
            do {
                await IPFSDaemon.shared.setupIPFS()
                if self.shouldAutoLaunchDaemon() {
                    try await IPFSDaemon.shared.launch()
                }
            } catch {
                debugPrint("Failed to launch: \(error.localizedDescription), will try again shortly.")
            }
        }
        RunLoop.main.add(Timer(timeInterval: Self.refreshRate, repeats: true) { _ in
            Task.detached(priority: .utility) {
                await self.updateStatus()
            }
        }, forMode: .common)
    }

    // MARK: -

    @MainActor
    func updateOperatingStatus(_ flag: Bool) {
        self.isOperating = flag
    }

    @MainActor
    func updateAPIPort(_ port: UInt16) {
        self.apiPort = port
    }

    @MainActor
    func updateSwarmPort(_ port: UInt16) {
        self.swarmPort = port
    }

    @MainActor
    func updateGatewayPort(_ port: UInt16) {
        self.gatewayPort = port
    }

    func getGateway() -> String {
        return "http://127.0.0.1:\(gatewayPort)"
    }

    // MARK: -

    func updateStatus() async {
        // verify webui online status
        let url = URL(string: "http://127.0.0.1:\(self.apiPort)/webui")!
        let request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 1
        )
        let onlineStatus: Bool
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let res = response as? HTTPURLResponse, res.statusCode == 200 {
                onlineStatus = true
            }
            else {
                onlineStatus = false
            }
        }
        catch {
            onlineStatus = false
        }

        // update current peers
        if onlineStatus {
            await PlanetStore.shared.updateServerInfo()
        }

        await MainActor.run {
            self.online = onlineStatus
        }
    }

    func updateAppSettings() {
        // refresh published folders
        Task.detached(priority: .utility) { @MainActor in
            PlanetPublishedServiceStore.shared.reloadPublishedFolders()
        }
        // process unpublished folders
        Task.detached(priority: .utility) {
            NotificationCenter.default.post(
                name: .dashboardProcessUnpublishedFolders,
                object: nil
            )
        }
        // update webview rule list.
        Task.detached(priority: .utility) {
            NotificationCenter.default.post(
                name: .updateRuleList,
                object: NSNumber(value: self.apiPort)
            )
        }
        // refresh key manager
        Task.detached(priority: .utility) { @MainActor in
            NotificationCenter.default.post(name: .keyManagerReloadUI, object: nil)
        }
    }

    // MARK: -

    private func shouldAutoLaunchDaemon() -> Bool {
        if UserDefaults.standard.value(forKey: Self.lastUserLaunchState) != nil, !UserDefaults.standard.bool(forKey: Self.lastUserLaunchState) {
            return false
        }
        return true
    }
}
