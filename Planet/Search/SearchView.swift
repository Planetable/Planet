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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title2)
                    .padding(.leading, 15)
                    .padding(.vertical, 10)
                    .padding(.trailing, 0)

                TextField("Type to Search", text: $planetStore.searchText)
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
                VStack(spacing: 0) {
//                    searchResult()
                    if result.count > 0 {
                        searchResultView()
                    } else {
                        List {
                        }.padding(0)
                    }
                }
                .id("top")
                .onChange(of: result.count) { _ in
                    proxy.scrollTo("top", anchor: .top)
                }
                .onChange(of: focusedResult) { _ in
                    if let id = focusedResult?.articleID {
                        proxy.scrollTo(id)
                    }
                }
            }
            Divider()
            statusView()
        }
        .frame(minWidth: 500, minHeight: 300)
        .onChange(of: planetStore.searchText) { _ in
            debounceSearch()
        }
        .onAppear {
            search()
        }
    }

    @State private var searchTimer: Timer?

    private let searchDebounceInterval: TimeInterval = 0.08  // 80 milliseconds

    private func debounceSearch() {
        // Invalidate and nullify the existing timer if it exists
        searchTimer?.invalidate()
        searchTimer = nil

        // Create and schedule a new timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: searchDebounceInterval, repeats: false)
        { _ in
            debugPrint("New search text length: \(self.planetStore.searchText.count)")
            if self.planetStore.searchText.count == 0 {
                self.result = []
            }
            else {
                self.search()
            }
            focusedResult = nil
        }
    }

    private func search() {
        let searchText = planetStore.searchText
        if searchText != "" {
            Task(priority: .userInitiated) {
                let items = await planetStore.searchAllArticles(text: searchText)
                DispatchQueue.main.async {
                    let latestSearchText = planetStore.searchText
                    if latestSearchText != searchText {
                        return
                    }
                    result = items
                }
            }
        }
    }

    @ViewBuilder
    private func searchResult() -> some View {
        if result.count > 0 {
            List {
                ForEach(result, id: \.self) { item in
                    searchResultRow(item)
                        .onTapGesture {
                            goToArticle(item)
                        }
                }
            }
            .padding(0)
            .listStyle(PlainListStyle())
        }
        else {
            List {
            }.padding(0)
        }
    }
    
    @ViewBuilder
    private func searchResultView() -> some View {
        ZStack {
            List {
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

                    Task(priority: .userInitiated) { @MainActor in
                        planetStore.selectedArticle = article
                        Task(priority: .userInitiated) { @MainActor in
                            NotificationCenter.default.post(name: .scrollToArticle, object: article)
                        }
                    }
                }
            case .following:
                if let planet = planetStore.followingPlanets.first(where: { $0.id == item.planetID }
                ), let article = planet.articles.first(where: { $0.id == item.articleID }) {
                    planetStore.selectedView = .followingPlanet(planet)

                    Task(priority: .userInitiated) { @MainActor in
                        planetStore.selectedArticle = article
                        Task(priority: .userInitiated) { @MainActor in
                            NotificationCenter.default.post(name: .scrollToArticle, object: article)
                        }
                    }
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

#Preview {
    SearchView()
}
