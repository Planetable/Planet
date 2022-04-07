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
        VStack {
            if articles.filter({ aa in
                return isArticleIncluded(aa)
            }).count > 0 {
                List(articles.filter({ a in
                    return isArticleIncluded(a)
                })) { article in
                    if let articleID = article.id {
                        NavigationLink(destination: PlanetArticleView(article: article)
                            .environmentObject(planetStore)
                            .frame(minWidth: 320), tag: articleID.uuidString, selection: $planetStore.selectedArticle) {
                                PlanetArticleItemView(article: article)
                            }
                            .contextMenu {
                                VStack {
                                    if articleIsMine() {
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

                                        Divider()

                                        Button {
                                            PlanetDataController.shared.refreshArticle(article)
                                        } label: {
                                            Text("Refresh")
                                        }
                                    } else {
                                        Button {
                                            if article.isRead == false {
                                                PlanetDataController.shared.updateArticleReadStatus(article: article, read: true)
                                            } else {
                                                PlanetDataController.shared.updateArticleReadStatus(article: article, read: false)
                                            }
                                        } label: {
                                            Text(article.isRead == false ? "Mark as Read" : "Mark as Unread")
                                        }
                                    }
                                    
                                    Button {
                                        if article.isStarred == false {
                                            PlanetDataController.shared.updateArticleStarStatus(article: article, starred: true)
                                        } else {
                                            PlanetDataController.shared.updateArticleStarStatus(article: article, starred: false)
                                        }
                                    } label: {
                                        Text(article.isStarred == false ? "Mark as Starred" : "Mark as Unstarred")
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
        }
        .navigationTitle(
            planetStore.currentPlanet == nil ? "Planet" : planetStore.currentPlanet.name ?? "Planet"
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
            if ts > today {
                return true
            } else {
                return false
            }
        case .unread:
            if a.isRead {
                if a.readElapsed < 60 {
                    return true
                } else {
                    return false
                }
            } else {
                return true
            }
        case .starred:
            if a.isStarred {
                return true
            } else {
                return false
            }
        }
    }

    private func articleIsMine() -> Bool {
        if let planet = planetStore.currentPlanet, planet.isMyPlanet() {
            return true
        }
        return false
    }

    private func articleStatus() -> String {
        if planetID == nil { return "" }
        guard articleIsMine() == false else { return "" }
        guard planetStore.currentPlanet != nil, planetStore.currentPlanet.name != "" else { return "" }
        let status = PlanetDataController.shared.getArticleStatus(byPlanetID: planetID!)
        if status.total == 0 {
            return "No articles yet."
        }
        return "\(status.total) articles, \(status.unread) unread."
    }
}
