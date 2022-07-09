import SwiftUI

struct ArticleView: View {
    static let noSelectionURL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
    @EnvironmentObject var planetStore: PlanetStore

    @State private var url = Self.noSelectionURL

    var body: some View {
        VStack {
            ArticleWebView(url: $url)
        }
            .frame(minWidth: 320)
            .background(
                Color(NSColor.textBackgroundColor)
            )
            .onChange(of: planetStore.selectedArticle) { newArticle in
                Task {
                    if let myArticle = newArticle as? MyArticleModel {
                        url = myArticle.publicIndexPath
                    } else
                    if let followingArticle = newArticle as? FollowingArticleModel {
                        if let webviewURL = await followingArticle.webviewURL {
                            url = webviewURL
                        } else {
                            url = Self.noSelectionURL
                        }
                    } else {
                        url = Self.noSelectionURL
                    }
                    NotificationCenter.default.post(name: .loadArticle, object: nil)
                }
            }
            .onChange(of: planetStore.selectedView) { _ in
                url = Self.noSelectionURL
                NotificationCenter.default.post(name: .loadArticle, object: nil)
            }
            .toolbar {
                switch planetStore.selectedView {
                case .myPlanet(let planet):
                    Button {
                        do {
                            try WriterStore.shared.newArticle(for: planet)
                        } catch {
                            PlanetStore.shared.alert(title: "Failed to launch writer")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    Button {
                        planetStore.isShowingPlanetInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                case .followingPlanet:
                    Button {
                        planetStore.isShowingPlanetInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                default:
                    Text("")
                }
            }
    }
}
