import SwiftUI

struct MyArticleItemView: View {
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
                HStack {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                HStack {
                    Text(article.created.mmddyyyy())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
            .contentShape(Rectangle())
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
                    if let planet = article.planet,
                       let index = planet.articles.firstIndex(of: article) {
                        planet.articles.remove(at: index)
                        article.delete()
                        if PlanetStore.shared.selectedArticle == article {
                            PlanetStore.shared.selectedArticle = nil
                        }
                    } else {
                        // TODO: internal error
                    }
                } label: {
                    Text("Delete")
                }
            }
    }
}
