import Foundation

class ArticleModel: ObservableObject, Identifiable, Equatable, Hashable {
    let id: UUID
    @Published var title: String
    @Published var content: String
    let created: Date
    @Published var starred: Date? = nil
    @Published var hasVideo: Bool = false
    @Published var videoFilename: String?

    init(id: UUID, title: String, content: String, created: Date, starred: Date?, hasVideo: Bool, videoFilename: String?) {
        self.id = id
        self.title = title
        self.content = content
        self.created = created
        self.starred = starred
        self.hasVideo = hasVideo
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
    let link: String
    let title: String
    let content: String
    let created: Date
}