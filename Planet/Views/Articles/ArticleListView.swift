import SwiftUI

struct ArticleListView: View {
    @EnvironmentObject var planetStore: PlanetStore

    var body: some View {
        VStack {
            if let articles = planetStore.selectedArticleList {
                if articles.isEmpty {
                    Text("No Article")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .regular))
                } else {
                    List(articles, id: \.self, selection: $planetStore.selectedArticle) { article in
                        if let myArticle = article as? MyArticleModel {
                            MyArticleItemView(article: myArticle)
                        }
                        if let followingArticle = article as? FollowingArticleModel {
                            FollowingArticleItemView(article: followingArticle)
                        }
                    }
                }
            } else {
                Text("No Planet Selected")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .regular))
            }
        }
            .navigationTitle(
                Text(planetStore.navigationTitle)
            )
            .navigationSubtitle(
                Text(planetStore.navigationSubtitle)
            )
            .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
            .toolbar {
                Text("")
            }
            .onReceive(NotificationCenter.default
            .publisher(for: .followingArticleReadChanged)) { aNotification in
                if let userObject = aNotification.object, let article = userObject as? FollowingArticleModel, let planet = article.planet {
                    debugPrint("FollowingArticleReadChanged: \(planet.name) -> \(article.title)")
                    Task { @MainActor in
                        planetStore.navigationSubtitle = planet.navigationSubtitle()
                    }
                }
            }
    }
}
