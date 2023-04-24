import SwiftUI

enum ListViewFilter: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
    case starred = "Starred"

    static let buttonLabels: [String: String] = [
        "All": "Show All",
        "Unread": "Show Only Unread",
        "Starred": "Show Only Starred",
    ]

    static let emptyLabels: [String: String] = [
        "All": "No Articles",
        "Unread": "No Unread Articles",
        "Starred": "No Starred Articles",
    ]
}

struct ArticleListView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @State var filter: ListViewFilter = .all
    @State var articles: [ArticleModel]? = []

    private func filterArticles(_ articles: [ArticleModel]) -> [ArticleModel]? {
        switch filter {
        case .all:
            return articles
        case .unread:
            return articles.filter {
                if let followingArticle = $0 as? FollowingArticleModel {
                    return followingArticle.read == nil
                }
                return false
            }
        case .starred:
            return articles.filter { $0.starred != nil }
        }
    }

    var body: some View {
        VStack {
            if let articles = articles {
                if articles.isEmpty {
                    Text(ListViewFilter.emptyLabels[filter.rawValue] ?? "No Articles")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .regular))
                }
                else {
                    List(articles, id: \.self, selection: $planetStore.selectedArticle) { article in
                        if let myArticle = article as? MyArticleModel {
                            MyArticleItemView(article: myArticle)
                        }
                        else if let followingArticle = article as? FollowingArticleModel {
                            FollowingArticleItemView(article: followingArticle)
                        }
                    }
                }
            }
            else {
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
            Menu {
                ForEach(ListViewFilter.allCases, id: \.self) { aFilter in
                    Button {
                        filter = aFilter
                    } label: {
                        HStack {
                            if filter == aFilter {
                                Image(systemName: "checkmark")
                            }
                            Text(ListViewFilter.buttonLabels[aFilter.rawValue] ?? aFilter.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20, alignment: .center)
            }
            .padding(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 0))
            .frame(width: 40, height: 20, alignment: .leading)
            .menuIndicator(.hidden)
        }
        .onAppear {
            articles = filterArticles(planetStore.selectedArticleList ?? [])
        }
        .onChange(of: planetStore.selectedArticleList) { newValue in
            articles = filterArticles(planetStore.selectedArticleList ?? [])
        }
        .onChange(of: filter) { newValue in
            articles = filterArticles(planetStore.selectedArticleList ?? [])
        }
        .onReceive(NotificationCenter.default.publisher(for: .followingArticleReadChanged)) {
            aNotification in
            if let userObject = aNotification.object,
                let article = userObject as? FollowingArticleModel, let planet = article.planet
            {
                debugPrint("FollowingArticleReadChanged: \(planet.name) -> \(article.title)")
                Task { @MainActor in
                    switch planetStore.selectedView {
                    case .unread:
                        debugPrint("Setting the new navigation subtitle for Unread")
                        if let articles = planetStore.selectedArticleList?.filter({ item in
                            if let followingArticle = item as? FollowingArticleModel {
                                return followingArticle.read == nil
                            }
                            return false
                        }) {
                            planetStore.navigationSubtitle = "\(articles.count) unread"
                        }
                    case .followingPlanet(let planet):
                        planetStore.navigationSubtitle = planet.navigationSubtitle()
                    default:
                        break
                    }

                }
            }
        }
    }
}
