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
                        .padding(.init(top: 6, leading: 4, bottom: 4, trailing: 4))
                        .visibility(article.read == nil ? .visible : .invisible)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text(article.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(article.humanizeCreated())
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    if let summary = article.summary, summary.count > 0 {
                        Text(summary)
                            .foregroundColor(.secondary)
                        if summary.count < 40 {
                            Spacer()
                        }
                    }
                    else if article.content.count > 0 {
                        Text(article.content.prefix(280))
                            .foregroundColor(.secondary)
                        if article.content.count < 40 {
                            Spacer()
                        }
                    }
                    else {
                        Spacer()
                    }
                }
                .frame(height: 56)
                HStack(spacing: 6) {
                    article.mediaLabels()
                }
            }
        }
        .padding(5)
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
                Menu("Star") {
                    ArticleSetStarView(article: article)
                }
                if article.starred != nil {
                    Button {
                        article.starred = nil
                        try? article.save()
                    } label: {
                        Text("Remove Star")
                    }
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
            Text(
                "Are you sure you want to delete this article? This action will remove it from your feed. However, if the article is still available on the source, it will reappear in your feed the next time you refresh it."
            ),
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
