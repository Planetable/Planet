//
//  PlanetArticleListView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


enum ArticleListType: Int32 {
    case planet = 0
    case today = 1
    case unread = 2
    case starred = 3
}

struct PlanetArticleListView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @Environment(\.managedObjectContext) private var context

    var planetID: UUID?
    var articles: FetchedResults<PlanetArticle>
    var type: ArticleListType = .planet

    @State private var isShowingConfirmation = false
    @State private var dialogDetail: PlanetArticle?

    var body: some View {
        VStack(content: {
            if !articles.filter(isArticleIncluded).isEmpty {
                List(articles.filter(isArticleIncluded), id: \.self, selection: $planetStore.currentArticle) { article in
                        if article.id != nil {
                            PlanetArticleItemView(article: article)
                            .contentShape(Rectangle())
                            .contextMenu {
                                VStack {
                                    if article.isMine {
                                        Button {
                                            PlanetWriterManager.shared.launchWriter(forArticle: article)
                                        } label: {
                                            Text("Edit Article")
                                        }
                                        Button {
                                            isShowingConfirmation = true
                                            dialogDetail = article
                                        } label: {
                                            Text("Delete Article")
                                        }
                                    } else {
                                        Button {
                                            article.isRead = !article.isRead
                                            PlanetDataController.shared.save()
                                        } label: {
                                            Text(article.isRead ? "Mark as Unread" : "Mark as Read")
                                        }
                                    }

                                    Button {
                                        article.isStarred = !article.isStarred
                                        PlanetDataController.shared.save()
                                    } label: {
                                        Text(article.isStarred ? "Mark as Unstarred" : "Mark as Starred")
                                    }

                                    Button {
                                        PlanetDataController.shared.copyPublicLinkOfArticle(article)
                                    } label: {
                                        Text("Copy Public Link")
                                    }

                                    Button {
                                        PlanetDataController.shared.openInBrowser(article)
                                    } label: {
                                        Text("Open in Browser")
                                    }
                                }
                            }
                        }

                }
            } else {
                Text("No Planet Selected")
                .foregroundColor(.secondary)
            }
        })
        .navigationTitle(
            Text(navigationTitle())
        )
        .navigationSubtitle(
            Text(articleStatus())
        )
        .confirmationDialog(
            Text("Are you sure you want to delete this article?"),
            isPresented: $isShowingConfirmation,
            presenting: dialogDetail
        ) { detail in
            Button(role: .destructive) {
                PlanetDataController.shared.removeArticle(detail)
            } label: {
                Text("Delete")
            }
        }
    }

    private func isArticleIncluded(_ a: PlanetArticle) -> Bool {
        if a.softDeleted != nil {
            return false
        }
        switch(type) {
        case .planet:
            if let id = a.planetID {
                return id == planetID
            }
            return false
        case .today:
            let t = Int32(Date().timeIntervalSince1970)
            let today = t - (t % 86400)
            let ts = Int32(a.created!.timeIntervalSince1970)
            return ts > today
        case .unread:
            return !a.isRead || a.readElapsed < 60
        case .starred:
            return a.isStarred
        }
    }

    private func navigationTitle() -> String {
        switch(type) {
        case .planet:
            if let planet = planetStore.currentPlanet, let name = planet.name {
                return name
            }
            return "Planet"
        case .today:
            return "Today"
        case .unread:
            return "Unread"
        case .starred:
            return "Starred"
        }
    }

    private func articleStatus() -> String {
        if planetID == nil || planetStore.currentPlanet == nil {
            return ""
        }
        if planetStore.currentPlanet!.isMyPlanet() {
            return ""
        }

        let status = PlanetDataController.shared.getArticleStatus(byPlanetID: planetID!)
        if status.total == 0 {
            return "No articles yet."
        }
        return "\(status.total) articles, \(status.unread) unread."
    }
}
