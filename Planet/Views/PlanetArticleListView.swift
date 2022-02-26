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
    
    var planetID: UUID?
    var articles: FetchedResults<PlanetArticle>?
    
    var body: some View {
        VStack {
            if let planetID = planetID, let articles = articles, articles.filter({ aa in
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
                    NavigationLink(destination: PlanetArticleView(article: article).environmentObject(planetStore), tag: article.id!.uuidString, selection: $planetStore.selectedArticle) {
                        VStack {
                            HStack {
                                Text(article.title ?? "")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            HStack {
                                Text(article.created?.dateDescription() ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .contextMenu {
                        VStack {
                            if let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet() {
                                Button {
                                    PlanetDataController.shared.removeArticle(article: article)
                                } label: {
                                    Text("Delete Article: \(article.title ?? "")")
                                }
                                Button {
                                    PlanetDataController.shared.refreshArticle(article)
                                } label: {
                                    Text("Refresh")
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
    }
}

struct PlanetArticleListView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetArticleListView()
    }
}
