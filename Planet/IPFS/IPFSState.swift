import Foundation
import os

@MainActor class IPFSState: ObservableObject {
    static let shared = IPFSState()

    @Published var online = false
    @Published var peers = 0
    @Published var isBootstrapping = true

    init() {
        Task {
            await IPFSDaemon.shared.launchDaemon()
        }
        RunLoop.main.add(Timer(timeInterval: 30, repeats: true) { timer in
            Task {
                await IPFSDaemon.shared.updateOnlineStatus()
                let onlineStatus = await self.online
                let bootstrappingStatus = await self.isBootstrapping
                if !onlineStatus && !bootstrappingStatus {
                    await IPFSDaemon.shared.launchDaemon()
                }
            }
        }, forMode: .common)
    }
}
