import Foundation

class ArticleModel: ObservableObject, Identifiable, Equatable, Hashable {
    let id: UUID
    @Published var title: String
    @Published var content: String
    let created: Date
    @Published var starred: Date? = nil
    @Published var videoFilename: String?

    var hasVideo: Bool {
        videoFilename != nil
    }

    init(id: UUID, title: String, content: String, created: Date, starred: Date?, videoFilename: String?) {
        self.id = id
        self.title = title
        self.content = content
        self.created = created
        self.starred = starred
        self.videoFilename = videoFilename
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: ArticleModel, rhs: ArticleModel) -> Bool {
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

struct PublicArticleModel: Codable {
    let id: UUID
    let link: String
    let title: String
    let content: String
    let created: Date
    let hasVideo: Bool?
    let videoFilename: String?
}
