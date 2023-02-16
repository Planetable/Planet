import Foundation
import SwiftUI

enum ArticleStarType: Int, Codable {
    case star = 0 // a yellow star.full
    case done = 1 // a blue checkmark.circle.fill
    case sparkles = 2 // a yellow sparkles
    case question = 3 // an orange questionmark.circle.fill
    case paperplane = 4 // a blue paperplane.circle.fill
}

class ArticleModel: ObservableObject, Identifiable, Equatable, Hashable {
    let id: UUID
    @Published var title: String
    @Published var content: String
    var created: Date
    @Published var starred: Date? = nil
    @Published var starType: ArticleStarType = .star
    @Published var videoFilename: String?
    @Published var audioFilename: String?
    @Published var attachments: [String]?

    var hasVideo: Bool {
        videoFilename != nil
    }

    var hasAudio: Bool {
        audioFilename != nil
    }

    init(
        id: UUID,
        title: String,
        content: String,
        created: Date,
        starred: Date?,
        starType: ArticleStarType = .star,
        videoFilename: String?,
        audioFilename: String?,
        attachments: [String]?
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.created = created
        self.starred = starred
        self.starType = starType
        self.videoFilename = videoFilename
        self.audioFilename = audioFilename
        self.attachments = attachments
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ArticleModel, rhs: ArticleModel) -> Bool {
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

    @ViewBuilder
    func starView() -> some View {
        switch starType {
        case .star:
            Image(systemName: "star.fill")
                .renderingMode(.original)
                .frame(width: 8, height: 8)
                .padding(.all, 4)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .renderingMode(.original)
                .frame(width: 8, height: 8)
                .padding(.all, 4)
        case .sparkles:
            Image(systemName: "sparkles")
                .renderingMode(.original)
                .frame(width: 8, height: 8)
                .padding(.all, 4)
        case .question:
            Image(systemName: "questionmark.circle.fill")
                .renderingMode(.original)
                .frame(width: 8, height: 8)
                .padding(.all, 4)
        case .paperplane:
            Image(systemName: "paperplane.circle.fill")
                .renderingMode(.original)
                .frame(width: 8, height: 8)
                .padding(.all, 4)
        }
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
    let hasAudio: Bool?
    let audioFilename: String?
    let audioDuration: Int?
    let audioByteLength: Int?
    let attachments: [String]?
    let heroImage: String?
}
