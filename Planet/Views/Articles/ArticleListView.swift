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
                        .toolbar {
                            Spacer()
                        }
                } else {
                    List(articles, id: \.self, selection: $planetStore.selectedArticle) { article in
                        if let myArticle = article as? MyArticleModel {
                            MyArticleItemView(article: myArticle)
                        }
                        if let followingArticle = article as? FollowingArticleModel {
                            FollowingArticleItemView(article: followingArticle)
                        }
                    }
                        .toolbar {
                            Spacer()
                        }
                }
            } else {
                Text("No Planet Selected")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .regular))
                    .toolbar {
                        Spacer()
                    }
            }
        }
            .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
    }
}
