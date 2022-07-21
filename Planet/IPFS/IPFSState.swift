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
                if !self.online && !self.isBootstrapping {
                    await IPFSDaemon.shared.launchDaemon()
                }
            }
        }, forMode: .common)
    }
}
