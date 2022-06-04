import Foundation
import CoreData

struct PlanetArticlePlaceholder: Codable, Identifiable, Hashable {
    var id: UUID
    var created: Date
    var read: Date
    var starred: Date
    var title: String
    var content: String
    var planetID: UUID
    var link: String
    var softDeleted: Date

    init(title: String, content: String) {
        self.id = UUID()
        self.created = Date()
        self.read = Date()
        self.starred = Date()
        self.title = title
        self.content = content
        self.planetID = UUID()
        self.link = "/\(self.id)/"
        self.softDeleted = Date()
    }
}


class PlanetArticle: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case id
        case created
        case read
        case starred
        case title
        case content
        case planetID
        case link
        case softDeleted
    }

    required convenience init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[.managedObjectContext] as? NSManagedObjectContext else {
            throw DecoderConfigurationError.missingManagedObjectContext
        }

        self.init(context: context)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        created = try container.decode(Date.self, forKey: .created)
        read = try container.decode(Date.self, forKey: .read)
        starred = try container.decode(Date.self, forKey: .starred)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        link = try container.decode(String.self, forKey: .link)
        planetID = try container.decode(UUID.self, forKey: .planetID)
        softDeleted = try container.decode(Date.self, forKey: .softDeleted)
    }

    convenience init() {
        self.init(context: PlanetDataController.shared.viewContext)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(created, forKey: .created)
        try container.encode(read, forKey: .read)
        try container.encode(starred, forKey: .starred)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(link, forKey: .link)
        try container.encode(planetID, forKey: .planetID)
        try container.encode(softDeleted, forKey: .softDeleted)
    }

    var isRead: Bool {
        get {
            read != nil
        }

        set {
            if newValue {
                read = Date()
            } else {
                read = nil
            }
        }
    }

    var readElapsed: Int32 {
        if read == nil {
            return 0
        } else {
            let now = Date()
            let diff = now.timeIntervalSince1970 - read!.timeIntervalSince1970
            return Int32(diff)
        }
    }

    var isStarred: Bool {
        get {
            starred != nil
        }

        set {
            if newValue {
                starred = Date()
            } else {
                starred = nil
            }
        }
    }

    var isMine: Bool {
        PlanetDataController.shared.getPlanet(id: planetID!)!.isMyPlanet()
    }

    var baseURL: URL {
        URLUtils.planetsPath.appendingPathComponent(planetID!.uuidString, isDirectory: true)
            .appendingPathComponent(id!.uuidString, isDirectory: true)
    }

    var infoURL: URL {
        baseURL.appendingPathComponent("article.json", isDirectory: false)
    }

    var indexURL: URL {
        baseURL.appendingPathComponent("index.html", isDirectory: false)
    }
}
