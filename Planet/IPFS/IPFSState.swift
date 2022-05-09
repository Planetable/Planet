import Foundation
import os

@MainActor class IPFSState: ObservableObject {
    static let shared = IPFSState()

    @Published var online = false
    @Published var peers = 0
}
