import SwiftUI

struct ArticleListView: View {
    @EnvironmentObject var planetStore: PlanetStore

    var articles: [ArticleModel]

    var body: some View {
        VStack {
            if articles.isEmpty {
                Text("No Article")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .regular))
                    .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Color(NSColor.textBackgroundColor)
                    ).toolbar {
                        // TODO: Content Type Switcher will go here
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
                }.toolbar {
                    // TODO: Content Type Switcher will go here
                    Spacer()
                }
            }
        }

            // .navigationTitle(
            //     // TODO: smart feed type enum
            // )
            // .navigationSubtitle(
            //     // TODO: smart feed type enum
            // )
    }
}
