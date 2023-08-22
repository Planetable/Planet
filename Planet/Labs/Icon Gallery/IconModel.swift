import SwiftUI


struct DockIcon: Decodable, Equatable, Hashable {
    let id: Int
    let groupID: Int
    let name: String
    let groupName: String
    let packageName: String
    let unlocked: Bool
}
