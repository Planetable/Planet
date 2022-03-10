//
//  PlanetArticleListView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetArticleListView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @Environment(\.managedObjectContext) private var context
    
    var planetID: UUID
    var articles: FetchedResults<PlanetArticle>
    
    var body: some View {
        VStack {
            if articles.filter({ aa in
                if let id = aa.planetID {
                    return id == planetID
                }
                return false
            }).count > 0 {
                List(articles.filter({ a in
                    if let id = a.planetID {
                        return id == planetID
                    }
                    return false
                })) { article in
                    if let articleID = article.id {
                        NavigationLink(destination: PlanetArticleView(article: article)
                                        .environmentObject(planetStore)
                                        .frame(minWidth: 320), tag: articleID.uuidString, selection: $planetStore.selectedArticle) {
                            VStack {
                                HStack {
                                    Text(article.title ?? "")
                                        .fontWeight(articleListFontWeight(article: article))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                HStack {
                                    Text(article.created?.dateDescription() ?? "")
                                        .fontWeight(articleListFontWeight(article: article))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .contextMenu {
                            VStack {
                                if articleIsMine() {
                                    Button {
                                        launchWriter(forArticle: article)
                                    } label: {
                                        Text("Update Article")
                                    }
                                    Button {
                                        PlanetDataController.shared.removeArticle(article: article)
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
                                        if articleListFontWeight(article: article) == .bold {
                                            PlanetManager.shared.updateArticleReadingStatus(article: article, read: true)
                                        } else {
                                            PlanetManager.shared.updateArticleReadingStatus(article: article, read: false)
                                        }
                                    } label: {
                                        Text(articleListFontWeight(article: article) == .bold ? "Mark as Read" : "Mark as Unread")
                                    }
                                }

                                Button {
                                    PlanetDataController.shared.copyPublicLinkOfArticle(article)
                                } label: {
                                    Text("Copy Public Link")
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
    }
    
    private func launchWriter(forArticle article: PlanetArticle) {
        let articleID = article.id!
        
        if planetStore.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                self.planetStore.activeWriterID = articleID
            }
            return
        }
        
        let writerView = PlanetWriterView(articleID: articleID, isEditing: true, title: article.title ?? "", content: article.content ?? "")
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 480, 320), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }
    
    private func articleIsMine() -> Bool {
        if let planet = planetStore.currentPlanet, planet.isMyPlanet() {
            return true
        }
        return false
    }
    
    private func articleStatus() -> String {
        guard articleIsMine() == false else { return "" }
        guard planetStore.currentPlanet != nil, planetStore.currentPlanet.name != "" else { return "" }
        let status = PlanetDataController.shared.getArticleStatus(byPlanetID: planetID)
        if status.total == 0 {
            return "No articles yet."
        }
        return "\(status.total) articles, \(status.unread) unread."
    }
    
    private func articleListFontWeight(article: PlanetArticle) -> Font.Weight {
        if articleIsMine() == false {
            if PlanetManager.shared.articleReadingStatus(article: article) == false {
                return .bold
            }
        }
        return .regular
    }
}
