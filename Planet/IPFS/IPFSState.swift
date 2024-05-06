import Foundation
import os


class IPFSState: ObservableObject {
    static let shared = IPFSState()

    @Published var online = false
    @Published var peers = 0
    @Published var isBootstrapping = true

    init() {
        debugPrint("IPFS State Manager Init")
        Task {
            await IPFSDaemon.shared.launch()
        }
        RunLoop.main.add(Timer(timeInterval: 30, repeats: true) { timer in
            Task {
                await IPFSDaemon.shared.updateOnlineStatus()
                let onlineStatus = self.online
                let bootstrappingStatus = self.isBootstrapping
                if !onlineStatus && !bootstrappingStatus {
                    await IPFSDaemon.shared.launch()
                }
            }
        }, forMode: .common)
    }
}
