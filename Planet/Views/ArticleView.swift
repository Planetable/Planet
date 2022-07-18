import SwiftUI

struct ArticleView: View {
    static let noSelectionURL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
    @EnvironmentObject var planetStore: PlanetStore

    @State private var url = Self.noSelectionURL
    @State private var isShowingAnalyticsPopover: Bool = false

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
                        isShowingAnalyticsPopover = true
                        Task {
                            await planet.updateTrafficAnalytics()
                        }
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                    }
                    .popover(isPresented: $isShowingAnalyticsPopover, arrowEdge: .bottom) {
                        VStack(spacing: 10) {
                            if let metrics = planet.metrics {
                                HStack {
                                    Text("Visitors Today")
                                        .frame(width: 120, alignment: .leading)
                                    Text("\(metrics.visitorsToday)")
                                        .fontWeight(.bold)
                                        .frame(width: 60, alignment: .trailing)
                                }
                                HStack {
                                    Text("Pageviews Today")
                                        .frame(width: 120, alignment: .leading)
                                    Text("\(metrics.pageviewsToday)")
                                        .fontWeight(.bold)
                                        .frame(width: 60, alignment: .trailing)
                                }
                            } else {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.5, anchor: .center)
                                    Text("Loading Analytics Data")
                                }
                            }
                            Divider()
                            Button("Full Analytics on Plausible.io") {
                                let url = URL(string: "https://plausible.io/olivida.eth.limo")!
                                if NSWorkspace.shared.open(url) {
                                }
                            }.buttonStyle(.link)
                        }.padding()

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
