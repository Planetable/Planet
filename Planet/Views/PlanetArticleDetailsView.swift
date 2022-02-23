//
//  PlanetArticleDetailsView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetArticleDetailsView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @Environment(\.managedObjectContext) private var context

    var article: PlanetArticle!

    var body: some View {
        VStack {
            if let article = article, let id = planetStore.selectedArticle, article.id != nil, id == article.id!.uuidString {
                ScrollView {
                    VStack {
                        HStack {
                            Text(article.title ?? "")
                                .font(.title)
                            Spacer()
                        }
                        HStack {
                            Text(article.created?.dateDescription() ?? "")
                                .font(.caption)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Text(article.content ?? "")
                                .font(.body)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                }
            } else {
                Text("No Article Selected")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(planetStore.currentPlanet == nil ? "Planet" : planetStore.currentPlanet.name ?? "Planet")
    }
}

struct PlanetArticleDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetArticleDetailsView()
    }
}
