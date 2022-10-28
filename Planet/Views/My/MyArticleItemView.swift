import SwiftUI

struct MyArticleItemView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    
    @ObservedObject var article: MyArticleModel

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack {
                Image(systemName: "star.fill")
                    .renderingMode(.original)
                    .frame(width: 8, height: 8)
                    .padding(.all, 4)
                    .visibility(article.starred == nil ? .invisible : .visible)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading) {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let summary = article.summary, summary.count > 0 {
                        Text(summary.prefix(280))
                            .foregroundColor(.secondary)
                        if summary.count < 40 {
                            Spacer()
                        }
                    } else if let content = article.content, content.count > 0 {
                        Text(content.prefix(280))
                            .foregroundColor(.secondary)
                        if content.count < 40 {
                            Spacer()
                        }
                    } else {
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
        .onDrag { NSItemProvider(object: article.id.uuidString as NSString ) }
        .onTapGesture { planetStore.selectedArticle = article }
        .contextMenu {
            VStack {
                Button {
                    do {
                        try WriterStore.shared.editArticle(for: article)
                    } catch {
                        PlanetStore.shared.alert(title: "Failed to launch writer")
                    }
                } label: {
                    Text("Edit Article")
                }
                Button {
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("Delete Article")
                }
                Button {
                    if article.starred == nil {
                        article.starred = Date()
                    } else {
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
            Text("Are you sure you want to delete this article?"),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(role: .destructive) {
                do {
                    if let planet = article.planet {
                        try article.delete()
                        planet.updated = Date()
                        try planet.save()
                        try planet.savePublic()
                        if PlanetStore.shared.selectedArticle == article {
                            PlanetStore.shared.selectedArticle = nil
                        }
                        if let selectedArticles = PlanetStore.shared.selectedArticleList,
                           selectedArticles.contains(article) {
                            PlanetStore.shared.refreshSelectedArticles()
                        }
                    }
                } catch {
                    PlanetStore.shared.alert(title: "Failed to delete article")
                }
            } label: {
                Text("Delete")
            }
        }
    }
}
