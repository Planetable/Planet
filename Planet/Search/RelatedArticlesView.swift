//
//  RelatedArticlesView.swift
//  Planet
//

import SwiftUI

struct RelatedArticlesView: View {
    @EnvironmentObject var planetStore: PlanetStore

    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title2)
                    .padding(.leading, 15)
                    .padding(.vertical, 10)
                    .padding(.trailing, 0)

                Text("Related Articles")
                    .font(.title2)

                Spacer()

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

            List {
                if results.isEmpty {
                    HStack {
                        Spacer()
                        Text(isSearching ? "Finding related articles..." : "No related articles found")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }

                ForEach(results, id: \.articleID) { item in
                    resultRow(item)
                        .id(item.articleID)
                        .onTapGesture {
                            goToArticle(item)
                        }
                }
            }
            .padding(0)
            .listStyle(PlainListStyle())

            Divider()

            HStack {
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding related articles...")
                        .foregroundColor(.secondary)
                } else if results.count > 1 {
                    Text("\(results.count) related articles")
                        .foregroundColor(.secondary)
                } else if results.count == 1 {
                    Text("1 related article")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }.padding(10)
        }
        .frame(width: 550, height: 547)
        .onAppear {
            loadRelatedArticles()
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
            planetStore.relatedArticleSource = nil
        }
    }

    private func loadRelatedArticles() {
        guard let articleID = planetStore.relatedArticleSource?.id else { return }
        isSearching = true
        searchTask = Task(priority: .userInitiated) {
            let items = SearchEmbedding.shared.findRelated(articleID: articleID)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.results = items
                self.isSearching = false
            }
        }
    }

    @ViewBuilder
    private func planetAvatarView(result: SearchResult, size: CGFloat) -> some View {
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

    @ViewBuilder
    private func resultRow(_ item: SearchResult) -> some View {
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
                Text(item.preview.isEmpty ? " " : item.preview)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(.leading, 2)
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private func goToArticle(_ item: SearchResult) {
        Task(priority: .userInitiated) { @MainActor in
            switch item.planetKind {
            case .my:
                if let planet = planetStore.myPlanets.first(where: { $0.id == item.planetID }),
                    let article = planet.articles.first(where: { $0.id == item.articleID })
                {
                    planetStore.selectedView = .myPlanet(planet)
                    NotificationCenter.default.post(
                        name: .scrollToSidebarItem,
                        object: "sidebar-my-\(planet.id.uuidString)"
                    )
                    await restoreSelectionAndScroll(
                        targetArticleID: item.articleID,
                        targetPlanetID: item.planetID,
                        isMyPlanet: true,
                        fallbackArticle: article
                    )
                }
            case .following:
                if let planet = planetStore.followingPlanets.first(where: {
                    $0.id == item.planetID
                }),
                    let article = planet.articles.first(where: { $0.id == item.articleID })
                {
                    planetStore.selectedView = .followingPlanet(planet)
                    NotificationCenter.default.post(
                        name: .scrollToSidebarItem,
                        object: "sidebar-following-\(planet.id.uuidString)"
                    )
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

    @MainActor
    private func restoreSelectionAndScroll(
        targetArticleID: UUID,
        targetPlanetID: UUID,
        isMyPlanet: Bool,
        fallbackArticle: ArticleModel
    ) async {
        let retryDelays: [UInt64] = [80_000_000, 180_000_000, 320_000_000]

        for delay in retryDelays {
            try? await Task.sleep(nanoseconds: delay)

            if isMyPlanet {
                guard case .myPlanet(let selectedPlanet) = planetStore.selectedView,
                    selectedPlanet.id == targetPlanetID
                else { continue }
            } else {
                guard case .followingPlanet(let selectedPlanet) = planetStore.selectedView,
                    selectedPlanet.id == targetPlanetID
                else { continue }
            }

            if let article = planetStore.selectedArticleList?.first(where: {
                $0.id == targetArticleID
            }) {
                planetStore.selectedArticle = article
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
                try? await Task.sleep(nanoseconds: 120_000_000)
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
                return
            }
        }

        planetStore.selectedArticle = fallbackArticle
        NotificationCenter.default.post(name: .scrollToArticle, object: fallbackArticle)
        try? await Task.sleep(nanoseconds: 120_000_000)
        NotificationCenter.default.post(name: .scrollToArticle, object: fallbackArticle)
    }
}
