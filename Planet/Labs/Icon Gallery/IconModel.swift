import SwiftUI


struct DockIcon: Decodable, Equatable, Hashable {
    let id: Int
    let groupID: Int
    let name: String
    let groupName: String
    let packageName: String
    let unlocked: Bool
    
    private func iconKey() -> String {
        #if DEBUG
        return "dev.xyz.planetable.Planet.icon.unlocked.id." + String(self.id)
        #else
        return "xyz.planetable.Planet.icon.unlocked.id." + String(self.id)
        #endif
    }
    
    func unlockIcon() throws {
        let now = Int(Date().timeIntervalSince1970)
        try KeychainHelper.shared.saveValue(String(now), forKey: self.iconKey())
    }
    
    func verifyIconStatus() -> Bool {
        if self.unlocked { return true }
        do {
            let value = try KeychainHelper.shared.loadValue(forKey: self.iconKey())
            return value != ""
        } catch {
            debugPrint("failed to verify dock icon status: \(error)")
        }
        return false
    }
}
