//
//  SearchView.swift
//  Planet
//
//  Created by Xin Liu on 12/6/23.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var planetStore: PlanetStore

    @State private var result: [SearchResult] = []
    @State private var focusedResult: SearchResult?

    @AppStorage("searchText") private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss
    private let searchEmptyAnchorID = "search-results-empty-anchor"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title2)
                    .padding(.leading, 15)
                    .padding(.vertical, 10)
                    .padding(.trailing, 0)

                TextField("Type to Search", text: $searchText)
                    .font(.title2)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .padding(.leading, 8)
                    .padding(.trailing, 10)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                        .padding(10)
                        .contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())
            }
            Divider()
            ScrollViewReader { proxy in
                searchResultView()
                    .onChange(of: result.map(\.articleID)) { _ in
                        Task { @MainActor in
                            await Task.yield()
                            if let firstID = result.first?.articleID {
                                proxy.scrollTo(firstID, anchor: .top)
                            } else {
                                proxy.scrollTo(searchEmptyAnchorID, anchor: .top)
                            }
                        }
                        if let focusedResult, !result.contains(focusedResult) {
                            self.focusedResult = nil
                        }
                    }
                    .onChange(of: focusedResult?.articleID) { id in
                        if let id = id {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
            }
            Divider()
            statusView()
        }
        .frame(minWidth: 500, minHeight: 300)
        .onChange(of: searchText) { _ in
            debounceSearch()
        }
        .onAppear {
            search()
        }
        .onDisappear {
            searchTimer?.invalidate()
            searchTimer = nil
            searchTask?.cancel()
            searchTask = nil
        }
    }

    @State private var searchTimer: Timer?

    private let searchDebounceInterval: TimeInterval = 0.08  // 80 milliseconds

    @MainActor
    private func restoreSelectionAndScroll(
        targetArticleID: UUID,
        targetPlanetID: UUID,
        isMyPlanet: Bool,
        fallbackArticle: ArticleModel
    ) async {
        // Retry because selectedView refreshes the article list asynchronously.
        let retryDelays: [UInt64] = [80_000_000, 180_000_000, 320_000_000]

        for delay in retryDelays {
            try? await Task.sleep(nanoseconds: delay)

            if isMyPlanet {
                guard case .myPlanet(let selectedPlanet) = planetStore.selectedView,
                    selectedPlanet.id == targetPlanetID
                else {
                    continue
                }
            } else {
                guard case .followingPlanet(let selectedPlanet) = planetStore.selectedView,
                    selectedPlanet.id == targetPlanetID
                else {
                    continue
                }
            }

            if let article = planetStore.selectedArticleList?.first(where: { $0.id == targetArticleID }) {
                planetStore.selectedArticle = article
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
                try? await Task.sleep(nanoseconds: 120_000_000)
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
                return
            }
        }

        // Fallback if list refresh is delayed but we still need to navigate.
        planetStore.selectedArticle = fallbackArticle
        NotificationCenter.default.post(name: .scrollToArticle, object: fallbackArticle)
        try? await Task.sleep(nanoseconds: 120_000_000)
        NotificationCenter.default.post(name: .scrollToArticle, object: fallbackArticle)
    }

    private func debounceSearch() {
        // Invalidate and nullify the existing timer if it exists
        searchTimer?.invalidate()
        searchTimer = nil

        // Create and schedule a new timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: searchDebounceInterval, repeats: false)
        { _ in
            debugPrint("New search text length: \(self.searchText.count)")
            if self.searchText.count == 0 {
                self.searchTask?.cancel()
                self.searchTask = nil
                self.result = []
            }
            else {
                self.search()
            }
            self.focusedResult = nil
        }
    }

    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchTask?.cancel()
            searchTask = nil
            result = []
            return
        }

        searchTask?.cancel()
        searchTask = Task(priority: .userInitiated) {
            let items = await planetStore.searchAllArticles(text: query)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard query == self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    return
                }
                self.result = items
            }
        }
    }

    @ViewBuilder
    private func searchResultView() -> some View {
        ZStack {
            List {
                if result.isEmpty {
                    HStack {
                        Spacer()
                        Text(searchText.isEmpty ? "Start typing to search" : "No matching articles")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                    .modifier(SearchEmptyRowSeparatorModifier())
                    .id(searchEmptyAnchorID)
                }

                ForEach(result, id: \.self) { item in
                    searchResultRow(item)
                        .id(item.articleID)
                        .onTapGesture {
                            goToArticle(item)
                        }
                }
            }
            .padding(0)
            .listStyle(PlainListStyle())
            .animation(nil, value: result.map(\.articleID))
            // arrow key navigation hack
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        // highlight first search result when return key event was sent to search field.
                        if focusedResult == nil && result.count > 0 {
                            focusedResult = result.first
                            return
                        }
                        guard let item = focusedResult else { return }
                        goToArticle(item)
                    } label: {
                        Text("")
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    Button {
                        goToPreviousSearchResult()
                    } label: {
                        Text("")
                    }
                    .keyboardShortcut(.upArrow, modifiers: [])
                    Button {
                        goToNextSearchResult()
                    } label: {
                        Text("")
                    }
                    .keyboardShortcut(.downArrow, modifiers: [])
                    Spacer()
                }
            }
            .opacity(0)
        }
    }

    private func goToNextSearchResult() {
        guard result.count > 0 else { return }
        if let currentFocusedResult = focusedResult {
            if let index = result.firstIndex(of: currentFocusedResult) {
                if index + 1 < result.count {
                    focusedResult = result[index + 1]
                }
            }
        } else {
            focusedResult = result.first
        }
    }

    private func goToPreviousSearchResult() {
        guard result.count > 0 else { return }
        if let currentFocusedResult = focusedResult {
            if let index = result.firstIndex(of: currentFocusedResult) {
                if index > 0 {
                    focusedResult = result[index - 1]
                }
            }
        } else {
            focusedResult = result.last
        }
    }

    @ViewBuilder
    func planetAvatarView(result: SearchResult, size: CGFloat) -> some View {
        switch result.planetKind {
        case .my:
            if let planet = PlanetStore.shared.myPlanets.first(where: { $0.id == result.planetID })
            {
                planet.avatarView(size: size)
            }
        case .following:
            if let planet = PlanetStore.shared.followingPlanets.first(where: {
                $0.id == result.planetID
            }) {
                planet.avatarView(size: size)
            }
        }
    }

    private func goToArticle(_ item: SearchResult) {
        Task(priority: .userInitiated) { @MainActor in
            /*
            planetStore.selectedView = .myPlanet(article.planet)
            Task(priority: .userInitiated) { @MainActor in
                planetStore.selectedArticle = article
                Task(priority: .userInitiated) { @MainActor in
                    NotificationCenter.default.post(name: .scrollToArticle, object: article)
                }
            }
            */
            switch item.planetKind {
            case .my:
                if let planet = planetStore.myPlanets.first(where: { $0.id == item.planetID }),
                    let article = planet.articles.first(where: { $0.id == item.articleID })
                {
                    planetStore.selectedView = .myPlanet(planet)
                    await restoreSelectionAndScroll(
                        targetArticleID: item.articleID,
                        targetPlanetID: item.planetID,
                        isMyPlanet: true,
                        fallbackArticle: article
                    )
                }
            case .following:
                if let planet = planetStore.followingPlanets.first(where: { $0.id == item.planetID }
                ), let article = planet.articles.first(where: { $0.id == item.articleID }) {
                    planetStore.selectedView = .followingPlanet(planet)
                    await restoreSelectionAndScroll(
                        targetArticleID: item.articleID,
                        targetPlanetID: item.planetID,
                        isMyPlanet: false,
                        fallbackArticle: article
                    )
                }
            }
        }
        dismiss()
    }

    @ViewBuilder
    private func searchResultRow(_ item: SearchResult) -> some View {
        ZStack {
            HStack(spacing: 10) {
                planetAvatarView(result: item, size: 32)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Text(item.title)
                            .lineLimit(1)
                            .font(.headline)

                        Spacer()

                        Text(item.planetName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                    Text(item.preview)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 4)
            }
            .padding(0)
            .padding(.leading, 2)
            .contentShape(Rectangle())
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .opacity(focusedResult == item ? 1.0 : 0)
                    .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private func statusView() -> some View {
        HStack {
            if result.count > 1 {
                Text("\(result.count) results")
                    .foregroundColor(.secondary)
            }
            else if result.count == 1 {
                Text("1 result")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Cancel") {
                dismiss()
            }
        }.padding(10)
    }
}

private struct SearchEmptyRowSeparatorModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.listRowSeparator(.hidden)
        } else {
            content
        }
    }
}

#Preview {
    SearchView()
}
