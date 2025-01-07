import SwiftUI
import UniformTypeIdentifiers

class ArticleListDropDelegate: DropDelegate {
    init() {}

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.itemProviders(for: [.fileURL]).count > 0
    }

    func performDrop(info: DropInfo) -> Bool {
        Task { @MainActor in
            let urls: [URL] = await PlanetQuickShareDropDelegate.processDropInfo(info)
            guard urls.count > 0 else { return }
            do {
                try PlanetQuickShareViewModel.shared.prepareFiles(urls)
                PlanetStore.shared.isQuickSharing = true
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to Create Post"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        return true
    }
}


struct ArticleListView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @StateObject private var viewModel = ArticleListViewModel()
    @State var articles: [ArticleModel]? = []

    let articleDropDelegate = ArticleListDropDelegate()

    private func filterArticles(_ articles: [ArticleModel]) -> [ArticleModel]? {
        switch viewModel.filter {
        case .all:
            return articles
        case .pages:
            return articles.filter {
                if let myArticle = $0 as? MyArticleModel {
                    return myArticle.articleType == .page
                }
                return false
            }
        case .videos:
            return articles.filter {
                if let myArticle = $0 as? MyArticleModel {
                    return myArticle.videoFilename != nil
                }
                if let followingArticle = $0 as? FollowingArticleModel {
                    return followingArticle.videoFilename != nil
                }
                return false
            }
        case .audios:
            return articles.filter {
                if let myArticle = $0 as? MyArticleModel {
                    return myArticle.audioFilename != nil
                }
                if let followingArticle = $0 as? FollowingArticleModel {
                    return followingArticle.audioFilename != nil
                }
                return false
            }
        case .nav:
            return articles.filter {
                if let myArticle = $0 as? MyArticleModel,
                    let isIncludedInNavigation = myArticle.isIncludedInNavigation
                {
                    return isIncludedInNavigation
                }
                return false
            }
        case .unread:
            return articles.filter {
                if let followingArticle = $0 as? FollowingArticleModel {
                    return followingArticle.read == nil
                }
                return false
            }
        case .starred:
            return articles.filter { $0.starred != nil }
        case .star:
            return articles.filter { $0.starred != nil && $0.starType == .star }
        case .plan:
            return articles.filter { $0.starred != nil && $0.starType == .plan }
        case .todo:
            return articles.filter { $0.starred != nil && $0.starType == .todo }
        case .done:
            return articles.filter { $0.starred != nil && $0.starType == .done }
        case .sparkles:
            return articles.filter { $0.starred != nil && $0.starType == .sparkles }
        case .heart:
            return articles.filter { $0.starred != nil && $0.starType == .heart }
        case .question:
            return articles.filter { $0.starred != nil && $0.starType == .question }
        case .paperplane:
            return articles.filter { $0.starred != nil && $0.starType == .paperplane }
        }
    }

    @ViewBuilder
    private func FilterIndicatorView(filter: ListViewFilter) -> some View {
        Image(systemName: ListViewFilter.imageNames[filter.rawValue] ?? "line.3.horizontal.circle")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20, alignment: .center)
    }

    init() {
        _viewModel = StateObject(wrappedValue: ArticleListViewModel.shared)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if viewModel.articles.isEmpty {
                    /*
                    Text(ListViewFilter.emptyLabels[filter.rawValue] ?? "No Articles")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .regular))
                    */
                    // It seems an empty List here gives us the expected Safe Area behavior
                    List {
                    }
                }
                else {
                    ScrollViewReader { proxy in
                        List(viewModel.articles, id: \.self, selection: $planetStore.selectedArticle) {
                            article in
                            HStack {
                                if let myArticle = article as? MyArticleModel {
                                    if #available(macOS 13.0, *) {
                                        MyArticleItemView(article: myArticle)
                                            .listRowSeparator(.visible)
                                    }
                                    else {
                                        MyArticleItemView(article: myArticle)
                                    }
                                }
                                else if let followingArticle = article as? FollowingArticleModel {
                                    if #available(macOS 13.0, *) {
                                        FollowingArticleItemView(article: followingArticle)
                                            .listRowSeparator(.visible)
                                    }
                                    else {
                                        FollowingArticleItemView(article: followingArticle)
                                    }
                                }
                            }.id(article.id)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .scrollToTopArticleList)) { n in
                            if let article = viewModel.articles.first {
                                debugPrint("Scrolling to top of Article List: \(article)")
                                withAnimation {
                                    proxy.scrollTo(article.id, anchor: .top)
                                }
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .scrollToArticle)) { n in
                            if let article = n.object as? ArticleModel {
                                debugPrint("Scrolling to Article: \(article)")
                                withAnimation {
                                    proxy.scrollTo(article.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Spacer()
                    .frame(height: geometry.safeAreaInsets.top)
            }
            .edgesIgnoringSafeArea(.vertical)
        }
        .navigationTitle(
            Text(planetStore.navigationTitle)
        )
        .navigationSubtitle(
            Text(planetStore.navigationSubtitle)
        )
        .frame(minWidth: 240, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .toolbar {
            Menu {
                ForEach(ListViewFilter.allCases, id: \.self) { aFilter in
                    Button {
                        viewModel.filter = aFilter
                    } label: {
                        HStack {
                            if viewModel.filter == aFilter {
                                Image(systemName: "checkmark")
                            }
                            else {
                                Image(
                                    systemName: ListViewFilter.imageNames[aFilter.rawValue]
                                        ?? "line.3.horizontal.circle"
                                )
                            }
                            Text(ListViewFilter.buttonLabels[aFilter.rawValue] ?? aFilter.rawValue)
                        }
                    }
                    if aFilter == .starred || aFilter == .star || aFilter == .done {
                        Divider()
                    }
                }
            } label: {
                FilterIndicatorView(filter: viewModel.filter)
            }
            .padding(EdgeInsets(top: 0, leading: 10, bottom: 1, trailing: 0))
            .frame(width: 40, height: 20, alignment: .leading)
            .menuIndicator(.hidden)
            .help(viewModel.filter.rawValue)
        }
        .onAppear {
            viewModel.articles = filterArticles(planetStore.selectedArticleList ?? []) ?? []
        }
        .onChange(of: planetStore.selectedArticleList) { _ in
            viewModel.articles = filterArticles(planetStore.selectedArticleList ?? []) ?? []
        }
        .onChange(of: viewModel.filter) { _ in
            viewModel.articles = filterArticles(planetStore.selectedArticleList ?? []) ?? []
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
        .onDrop(of: [.fileURL], delegate: articleDropDelegate)
    }
}
