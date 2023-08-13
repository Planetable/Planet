import Foundation
import SwiftUI

enum ArticleType: Int, Codable, CaseIterable {
    case blog = 0  // include in the RSS feed, default type
    case page = 1  // does not include in the RSS feed
}

enum ArticleStarType: Int, Codable, CaseIterable {
    case star = 0  // a yellow star.full
    case done = 1  // a blue checkmark.circle.fill
    case sparkles = 2  // a yellow sparkles
    case heart = 3  // a red heart.fill
    case question = 4  // an orange questionmark.circle.fill
    case paperplane = 5  // a blue paperplane.circle.fill
    case todo = 6  // a secondary color circle
    case plan = 7  // a secondary color circle.dotted
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

    func humanizeCreated() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: created)
    }

    @MainActor
    @ViewBuilder
    func mediaLabels(includeSpacers: Bool = true) -> some View {
        if hasVideo || hasAudio {
            HStack(spacing: 4) {
                if hasAudio, let audioFilename = audioFilename {
                    Text(Image(systemName: "headphones"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(audioFilename)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if hasVideo, let videoFilename = videoFilename {
                    Text(Image(systemName: "video"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(videoFilename)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.init(top: 3, leading: 4, bottom: 3, trailing: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
        }
        else {
            if let attachments = attachments, attachments.count > 0,
                let firstAttachment = attachments.first
            {
                HStack(spacing: 4) {
                    if [".jpg", ".png", ".gif", ".tiff", ".avif", ".heif", ".webp"].contains(where: firstAttachment.lowercased().hasSuffix)
                    {
                        Text(Image(systemName: "photo"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    else if [".zip", ".rar", ".7z", ".sit", ".gz", ".bz2"].contains(where: firstAttachment.lowercased().hasSuffix) {
                        Text(Image(systemName: "doc.zipper"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    else {
                        Text(Image(systemName: "paperclip"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(firstAttachment)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.init(top: 3, leading: 4, bottom: 3, trailing: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
                if attachments.count > 1 {
                    Text("& \(attachments.count - 1) more")
                        .lineLimit(1)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            else {
                if includeSpacers {
                    Text(" ")
                        .font(.caption)
                        .foregroundColor(.clear)
                    Spacer()
                    Text(" ")
                        .font(.caption)
                        .foregroundColor(.clear)
                }
            }
        }
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

    func saveArticle() throws {
        if let myArticle = self as? MyArticleModel {
            try? myArticle.save()
        }
        if let followingArticle = self as? FollowingArticleModel {
            debugPrint(
                "About to save FollowingArticle: \(self.title) UUID=\(self.id) StarType=\(self.starType)"
            )
            do {
                try followingArticle.save()
                debugPrint("Successfully saved FollowingArticle: \(self.title) UUID=\(self.id)")
            }
            catch {
                debugPrint(
                    "An error occurred when saving FollowingArticle: \(self.title) error: \(error)"
                )
            }
        }
    }

    @ViewBuilder
    func starView() -> some View {
        if starred == nil {
            Image(systemName: "star")
                .renderingMode(.original)
                .frame(width: 8, height: 8)
                .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
        }
        else {
            switch starType {
            case .star:
                Image(systemName: "star.fill")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            case .plan:
                Image(systemName: "circle.dotted")
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            case .todo:
                Image(systemName: "circle")
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            case .sparkles:
                Image(systemName: "sparkles")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            case .heart:
                Image(systemName: "heart.fill")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            case .question:
                Image(systemName: "questionmark.circle.fill")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            case .paperplane:
                Image(systemName: "paperplane.circle.fill")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
                    .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
            }
        }
    }
}
