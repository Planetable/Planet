import SwiftSoup
import SwiftUI
import UniformTypeIdentifiers

class ArticleListDropDelegate: DropDelegate {
    private static let dragAlertPresentationDelay: UInt64 = 500_000_000

    private enum TextImportDropError: LocalizedError {
        case multipleTextFilesWithAttachments
        case targetPlanetRequired

        var errorDescription: String? {
            switch self {
            case .multipleTextFilesWithAttachments:
                return L10n("Drop either a single Markdown or text file with attachments, or multiple Markdown/text files by themselves to import them as separate articles.")
            case .targetPlanetRequired:
                return L10n("Select one of your planets before dropping a Markdown or text file.")
            }
        }
    }

    private struct ImportedTextDocument {
        let title: String
        let content: String
    }

    init() {}

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.itemProviders(for: [.fileURL]).count > 0
    }

    private static func droppedFileURLs(from info: DropInfo) async -> [URL] {
        var urls: [URL] = []
        var seenPaths = Set<String>()
        for provider in info.itemProviders(for: [.fileURL]) {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                let data = item as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            {
                let path = url.standardizedFileURL.path
                if seenPaths.insert(path).inserted {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    private static func isImportableTextFile(_ url: URL) -> Bool {
        ["md", "markdown", "txt"].contains(url.pathExtension.lowercased())
    }

    private static func withSecurityScopedAccess<T>(to urls: [URL], _ body: () throws -> T) throws -> T {
        let scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }
        return try body()
    }

    private static func loadTextDocument(from url: URL) throws -> ImportedTextDocument {
        var usedEncoding = String.Encoding.utf8.rawValue
        let content = try NSString(contentsOf: url, usedEncoding: &usedEncoding) as String
        if let extracted = extractLeadingMarkdownH1(from: content) {
            return ImportedTextDocument(title: extracted.title, content: extracted.content)
        }
        return ImportedTextDocument(title: "", content: content)
    }

    private static func sortedFileURLs(_ urls: [URL]) -> [URL] {
        urls.sorted {
            let lhsName = $0.lastPathComponent
            let rhsName = $1.lastPathComponent
            let comparison = lhsName.localizedStandardCompare(rhsName)
            if comparison == .orderedSame {
                return $0.standardizedFileURL.path < $1.standardizedFileURL.path
            }
            return comparison == .orderedAscending
        }
    }

    private static func resolvedImportedTitle(for document: ImportedTextDocument, sourceURL: URL) -> String {
        let extractedTitle = document.title.trim()
        if !extractedTitle.isEmpty {
            return extractedTitle
        }

        let fallbackTitle = sourceURL.deletingPathExtension().lastPathComponent.sanitized().trim()
        return fallbackTitle.isEmpty ? "Untitled" : fallbackTitle
    }

    private static func importedArticleDate(for url: URL, fallbackOffset: Int) -> Date {
        if let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey]),
           let importedDate = resourceValues.contentModificationDate ?? resourceValues.creationDate
        {
            return importedDate
        }
        return Date().addingTimeInterval(TimeInterval(-fallbackOffset))
    }

    private static func configureImportedArticle(_ article: MyArticleModel) {
        guard let contentHTML = CMarkRenderer.renderMarkdownHTML(markdown: article.content) else {
            return
        }
        article.contentRendered = contentHTML
        if let soup = try? SwiftSoup.parseBodyFragment(contentHTML),
           let summary = try? soup.text()
        {
            if summary.count > 280 {
                article.summary = String(summary.prefix(280)) + "..."
            } else {
                article.summary = summary
            }
        }
    }

    @MainActor
    private static func importTextDocuments(_ textDocumentURLs: [URL], to planet: MyPlanetModel) throws {
        let sortedURLs = sortedFileURLs(textDocumentURLs)
        var importedArticles: [MyArticleModel] = []
        var duplicateCount = 0

        let existingKeys: Set<[String]> = Set(
            (planet.articles ?? []).map { [$0.title, $0.content] }
        )

        for (index, url) in sortedURLs.enumerated() {
            let document = try loadTextDocument(from: url)
            let title = resolvedImportedTitle(for: document, sourceURL: url)
            if existingKeys.contains([title, document.content]) {
                duplicateCount += 1
                continue
            }
            let article = try MyArticleModel.compose(
                link: nil,
                date: importedArticleDate(for: url, fallbackOffset: index),
                title: title,
                content: document.content,
                summary: nil,
                planet: planet
            )
            configureImportedArticle(article)
            try article.save()
            try article.savePublic()
            importedArticles.append(article)
        }

        guard !importedArticles.isEmpty else {
            if duplicateCount > 0 {
                showDuplicatesSkippedAlert(count: duplicateCount)
            }
            return
        }

        let updatedArticles = ((planet.articles ?? []) + importedArticles).sorted(by: MyArticleModel.reorder)
        planet.articles = updatedArticles
        planet.tags = planet.consolidateTags()
        planet.updated = Date()
        try planet.copyTemplateAssets()
        try planet.save()

        let selectedArticleList: [ArticleModel] = updatedArticles
        PlanetStore.shared.selectedArticleList = selectedArticleList
        PlanetStore.shared.navigationTitle = planet.name
        PlanetStore.shared.navigationSubtitle = planet.navigationSubtitle()
        ArticleListViewModel.shared.articles = filteredArticles(
            selectedArticleList,
            filter: ArticleListViewModel.shared.filter
        )

        if let selectedImportedArticle = importedArticles.sorted(by: MyArticleModel.reorder).first,
           let matchingArticle = PlanetStore.shared.selectedArticleList?.first(where: {
               $0.id == selectedImportedArticle.id
           })
        {
            PlanetStore.shared.selectedArticle = matchingArticle
            NotificationCenter.default.post(name: .scrollToArticle, object: matchingArticle)
        }

        Task(priority: .userInitiated) {
            do {
                try await planet.savePublic()
                try await Task.sleep(nanoseconds: 500_000_000)
                try await planet.publish()

                for article in importedArticles {
                    await article.prewarm()
                }
            } catch {
                print("During batch importing articles into \(planet.name), an error occurred: \(error)")
            }
        }

        if duplicateCount > 0 {
            showDuplicatesSkippedAlert(count: duplicateCount)
        }
    }

    @MainActor
    private static func showDuplicatesSkippedAlert(count: Int) {
        let alert = NSAlert()
        alert.messageText = count == 1
            ? L10n("1 Duplicate Article Skipped")
            : String(format: L10n("%d Duplicate Articles Skipped"), count)
        alert.informativeText = count == 1
            ? L10n("1 file was not imported because its title and content matched an existing article.")
            : String(format: L10n("%d files were not imported because their title and content matched existing articles."), count)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n("OK"))
        alert.runModal()
    }

    private static func extractLeadingMarkdownH1(from content: String) -> (title: String, content: String)? {
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalizedContent.components(separatedBy: "\n")

        guard let headingIndex = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            return nil
        }

        let line = lines[headingIndex].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("#"), !line.hasPrefix("##") else {
            return nil
        }

        let remainder = line.dropFirst()
        guard let first = remainder.first, first == " " || first == "\t" else {
            return nil
        }

        var title = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.replacingOccurrences(of: #"\s#+\s*$"#, with: "", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        lines.remove(at: headingIndex)
        if headingIndex < lines.count,
            lines[headingIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            lines.remove(at: headingIndex)
        }

        return (title: title, content: lines.joined(separator: "\n"))
    }

    @MainActor
    private static func handleTextDocumentDrop(_ fileURLs: [URL]) async throws -> Bool {
        let textDocumentURLs = sortedFileURLs(fileURLs.filter { isImportableTextFile($0) })
        guard !textDocumentURLs.isEmpty else {
            return false
        }
        guard case .myPlanet(let planet)? = PlanetStore.shared.selectedView else {
            throw TextImportDropError.targetPlanetRequired
        }

        let attachmentURLs = fileURLs.filter { !textDocumentURLs.contains($0) }
        if textDocumentURLs.count == 1 {
            try withSecurityScopedAccess(to: fileURLs) {
                let textDocumentURL = textDocumentURLs[0]
                let document = try loadTextDocument(from: textDocumentURL)
                try WriterStore.shared.newArticle(
                    for: planet,
                    initialTitle: resolvedImportedTitle(for: document, sourceURL: textDocumentURL),
                    initialContent: document.content,
                    attachmentURLs: attachmentURLs,
                    forceNewDraft: true
                )
            }
        } else {
            guard attachmentURLs.isEmpty else {
                throw TextImportDropError.multipleTextFilesWithAttachments
            }
            // Yield so AppKit can finish dismissing the drag visuals before the modal alert blocks the main thread.
            try? await Task.sleep(nanoseconds: dragAlertPresentationDelay)
            let confirm = NSAlert()
            confirm.messageText = String(format: L10n("Import %d Files?"), textDocumentURLs.count)
            confirm.informativeText = L10n("Each Markdown or text file will be imported as a separate article.")
            confirm.alertStyle = .informational
            confirm.addButton(withTitle: L10n("Import"))
            confirm.addButton(withTitle: L10n("Cancel"))
            guard confirm.runModal() == .alertFirstButtonReturn else {
                return true
            }
            try withSecurityScopedAccess(to: textDocumentURLs) {
                try importTextDocuments(textDocumentURLs, to: planet)
            }
        }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        Task { @MainActor in
            do {
                let fileURLs = await Self.droppedFileURLs(from: info)
                if try await Self.handleTextDocumentDrop(fileURLs) {
                    if #available(macOS 14.0, *) {
                        NSApp.activate()
                    } else {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    return
                }

                let urls: [URL] = await PlanetQuickShareDropDelegate.processDropInfo(info)
                guard urls.count > 0 else { return }
                try PlanetQuickShareViewModel.shared.prepareFiles(urls)
                PlanetStore.shared.isQuickSharing = true
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } catch {
                // Give AppKit time to clear drag visuals before the modal alert appears.
                try? await Task.sleep(nanoseconds: Self.dragAlertPresentationDelay)
                let alert = NSAlert()
                alert.messageText = L10n("Failed to Create Post")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: L10n("OK"))
                alert.runModal()
            }
        }
        return true
    }
}


private func filteredArticles(_ articles: [ArticleModel], filter: ListViewFilter) -> [ArticleModel] {
    switch filter {
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


private struct FilterButtonCompatModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
        } else {
            content
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 1, trailing: 0))
                .frame(width: 40, height: 20, alignment: .leading)
        }
    }
}

struct ArticleListView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @StateObject private var viewModel = ArticleListViewModel()
    @State var articles: [ArticleModel]? = []
    @State private var pendingScrollArticleID: UUID?
    @State private var pendingScrollTask: Task<Void, Never>?

    let articleDropDelegate = ArticleListDropDelegate()

    private func scrollToArticle(_ articleID: UUID, proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation {
                proxy.scrollTo(articleID, anchor: .center)
            }
        } else {
            proxy.scrollTo(articleID, anchor: .center)
        }
    }

    private func retryPendingArticleScroll(proxy: ScrollViewProxy) {
        guard let articleID = pendingScrollArticleID else {
            return
        }
        scrollToArticle(articleID, proxy: proxy, animated: false)
    }

    private func requestArticleScroll(_ articleID: UUID, proxy: ScrollViewProxy) {
        pendingScrollArticleID = articleID
        scrollToArticle(articleID, proxy: proxy, animated: true)

        pendingScrollTask?.cancel()
        pendingScrollTask = Task { @MainActor in
            // Re-apply after selectedView/list updates to keep the row visible.
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, pendingScrollArticleID == articleID else {
                return
            }
            retryPendingArticleScroll(proxy: proxy)

            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, pendingScrollArticleID == articleID else {
                return
            }
            retryPendingArticleScroll(proxy: proxy)
            pendingScrollArticleID = nil
        }
    }

    private func filterArticles(_ articles: [ArticleModel]) -> [ArticleModel]? {
        filteredArticles(articles, filter: viewModel.filter)
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
                    Text(filter.localizedEmptyLabel)
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
                            let selected = planetStore.selectedArticle?.id == article.id
                            HStack {
                                if let myArticle = article as? MyArticleModel {
                                    if #available(macOS 13.0, *) {
                                        MyArticleItemView(article: myArticle, isSelected: selected)
                                            .listRowSeparator(.visible)
                                    }
                                    else {
                                        MyArticleItemView(article: myArticle, isSelected: selected)
                                    }
                                }
                                else if let followingArticle = article as? FollowingArticleModel {
                                    if #available(macOS 13.0, *) {
                                        FollowingArticleItemView(article: followingArticle, isSelected: selected)
                                            .listRowSeparator(.visible)
                                    }
                                    else {
                                        FollowingArticleItemView(article: followingArticle, isSelected: selected)
                                    }
                                }
                            }.id(article.id)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .scrollToTopArticleList)) { n in
                            if let article = viewModel.articles.first {
                                debugPrint("Scrolling to top of Article List: \(article)")
                                pendingScrollTask?.cancel()
                                pendingScrollTask = nil
                                pendingScrollArticleID = nil
                                withAnimation {
                                    proxy.scrollTo(article.id, anchor: .top)
                                }
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .scrollToArticle)) { n in
                            if let article = n.object as? ArticleModel {
                                debugPrint("Scrolling to Article: \(article)")
                                requestArticleScroll(article.id, proxy: proxy)
                            }
                        }
                        .onChange(of: planetStore.selectedView?.stringValue) { _ in
                            guard pendingScrollArticleID != nil else {
                                return
                            }
                            Task { @MainActor in
                                await Task.yield()
                                retryPendingArticleScroll(proxy: proxy)
                            }
                        }
                        .onChange(of: viewModel.articlesVersion) { _ in
                            guard pendingScrollArticleID != nil else {
                                return
                            }
                            Task { @MainActor in
                                await Task.yield()
                                retryPendingArticleScroll(proxy: proxy)
                            }
                        }
                        .onChange(of: planetStore.selectedArticle?.id) { id in
                            guard let pendingID = pendingScrollArticleID, pendingID == id else {
                                return
                            }
                            Task { @MainActor in
                                await Task.yield()
                                retryPendingArticleScroll(proxy: proxy)
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
        .frame(minWidth: 240, idealWidth: UserDefaults.standard.double(forKey: "articleListWidth") > 0 ? UserDefaults.standard.double(forKey: "articleListWidth") : 240) // See https://github.com/Planetable/Planet/issues/393
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
                            Text(aFilter.localizedButtonLabel)
                        }
                    }
                    if aFilter == .starred || aFilter == .star || aFilter == .done {
                        Divider()
                    }
                }
            } label: {
                FilterIndicatorView(filter: viewModel.filter)
            }
            .modifier(FilterButtonCompatModifier())
            .menuIndicator(.hidden)
            .help(viewModel.filter.localizedTitle)
        }
        .onAppear {
            viewModel.articles = filterArticles(planetStore.selectedArticleList ?? []) ?? []
        }
        .onChange(of: planetStore.selectedArticleListVersion) { _ in
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
                    planetStore.updateNavigationSubtitle()
                }
            }
        }
        .onDrop(of: [.fileURL], delegate: articleDropDelegate)
        .onWidthChange { newWidth in
            @AppStorage("articleListWidth") var articleListWidth = 240.0
            articleListWidth = newWidth
        }
        .onDisappear {
            pendingScrollTask?.cancel()
            pendingScrollTask = nil
            pendingScrollArticleID = nil
        }
    }
}
