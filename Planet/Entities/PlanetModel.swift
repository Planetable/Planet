import Foundation

class PlanetModel: Equatable, Identifiable, Hashable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var about: String
    let created: Date

    init(id: UUID, name: String, about: String, created: Date) {
        self.id = id
        self.name = name
        self.about = about
        self.created = created
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: PlanetModel, rhs: PlanetModel) -> Bool {
        if lhs === rhs {
            return true
        }
        if type(of: lhs) != type(of: rhs) {
            return false
        }
        if lhs.id != rhs.id {
            return false
        }
        return true
    }
}

struct PublicPlanetModel: Codable {
    let id: UUID
    let name: String
    let about: String
    let ipns: String
    let created: Date
    let updated: Date
    let articles: [PublicArticleModel]
}
