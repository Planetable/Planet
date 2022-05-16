import Foundation
import os

@MainActor class IPFSState: ObservableObject {
    static let shared = IPFSState()

    @Published var online = false
    @Published var peers = 0

    init() {
        Task.init {
            await IPFSDaemon.shared.launchDaemon()
        }
        RunLoop.main.add(Timer(timeInterval: 30, repeats: true) { timer in
            Task.init {
                await IPFSDaemon.shared.updateOnlineStatus()
                if !(IPFSState.shared.online) {
                    await IPFSDaemon.shared.launchDaemon()
                }
            }
        }, forMode: .common)
    }
}
