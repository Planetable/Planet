import SwiftUI

struct FollowingArticleItemView: View {
    @ObservedObject var article: FollowingArticleModel

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack {
                if article.starred != nil {
                    article.starView()
                }
                else {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .padding(.all, 4)
                        .visibility(article.read == nil ? .visible : .invisible)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading) {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let summary = article.summary, summary.count > 0 {
                        Text(summary)
                            .foregroundColor(.secondary)
                        if summary.count < 40 {
                            Spacer()
                        }
                    }
                    else if let content = article.content, content.count > 0 {
                        Text(content.prefix(280))
                            .foregroundColor(.secondary)
                        if content.count < 40 {
                            Spacer()
                        }
                    }
                    else {
                        Spacer()
                    }
                }
                .frame(height: 48)
                HStack(spacing: 6) {
                    Text(article.created.mmddyyyy())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if article.hasAudio {
                        Text(Image(systemName: "headphones"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if article.hasVideo {
                        Text(Image(systemName: "video"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            VStack {
                Button {
                    if article.read == nil {
                        article.read = Date()
                    }
                    else {
                        article.read = nil
                    }
                    try? article.save()
                } label: {
                    Text(article.read == nil ? "Mark as Read" : "Mark as Unread")
                }
                Button {
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("Delete Article")
                }
                if article.starred != nil {
                    Menu("Set Article Star Type") {
                        Button {
                            article.starType = .star
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Star")
                            }
                        }
                        Divider()
                        Button {
                            article.starType = .plan
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "circle.dotted")
                                Text("Plan")
                            }
                        }
                        Button {
                            article.starType = .todo
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "circle")
                                Text("To Do")
                            }
                        }
                        Button {
                            article.starType = .done
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done")
                            }
                        }
                        Divider()
                        Button {
                            article.starType = .sparkles
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Sparkles")
                            }
                        }
                        Button {
                            article.starType = .heart
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("Heart")
                            }
                        }
                        Button {
                            article.starType = .question
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                Text("Question")
                            }
                        }
                        Button {
                            article.starType = .paperplane
                            try? article.save()
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.circle.fill")
                                Text("Paperplane")
                            }
                        }
                    }
                }
                Button {
                    if article.starred == nil {
                        article.starred = Date()
                    }
                    else {
                        article.starred = nil
                    }
                    try? article.save()
                } label: {
                    Text(article.starred == nil ? "Star" : "Unstar")
                }
                Button {
                    if let url = article.browserURL {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                } label: {
                    Text("Copy Public Link")
                }
                Button {
                    if let url = article.browserURL {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open in Browser")
                }
            }
        }
        .confirmationDialog(
            Text("Are you sure you want to delete this article? This action will remove it from your feed. However, if the article is still available on the source, it will reappear in your feed the next time you refresh it."),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(role: .destructive) {
                if PlanetStore.shared.selectedArticle == article {
                    PlanetStore.shared.selectedArticle = nil
                }
                article.delete()
                if case .followingPlanet(let selectedPlanet) = PlanetStore.shared.selectedView {
                    if let index = selectedPlanet.articles.firstIndex(of: article) {
                        selectedPlanet.articles.remove(at: index)
                    }
                }
                PlanetStore.shared.refreshSelectedArticles()
            } label: {
                Text("Delete")
            }
        }
    }
}
