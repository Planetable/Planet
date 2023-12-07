//
//  SearchView.swift
//  Planet
//
//  Created by Xin Liu on 12/6/23.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var planetStore: PlanetStore

    @State private var result: [MyArticleModel] = []

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
                    searchResult()
                }.id("top")
                    .onChange(of: result.count) { _ in
                        proxy.scrollTo("top", anchor: .top)
                    }
            }
            Divider()
            statusView()
        }
        .frame(minWidth: 500, minHeight: 300)
        .onChange(of: planetStore.searchText) { _ in
            debugPrint("New search text length: \(planetStore.searchText.count)")
            if planetStore.searchText.count == 0 {
                DispatchQueue.main.async {
                    result = []
                }
            }
            else {
                search()
            }
        }
        .onAppear {
            search()
        }
    }

    private func search() {
        let searchText = planetStore.searchText
        if searchText != "" {
            Task(priority: .userInitiated) {
                let articles = await planetStore.searchArticles(text: searchText)
                DispatchQueue.main.async {
                    let latestSearchText = planetStore.searchText
                    if latestSearchText != searchText {
                        return
                    }
                    result = articles
                }
            }
        }
    }

    @ViewBuilder
    private func searchResult() -> some View {
        if result.count > 0 {
            List {
                ForEach(result, id: \.self) { article in
                    searchResultRow(article)
                        .onTapGesture {
                            goToArticle(article)
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

    private func goToArticle(_ article: MyArticleModel) {
        Task(priority: .userInitiated) { @MainActor in
            planetStore.selectedView = .myPlanet(article.planet)
            Task(priority: .userInitiated) { @MainActor in
                planetStore.selectedArticle = article
            }
        }
        dismiss()
    }

    @ViewBuilder
    private func searchResultRow(_ item: MyArticleModel) -> some View {
        HStack(spacing: 10) {
            item.planet.avatarView(size: 32)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text(item.title)
                        .lineLimit(1)
                        .font(.headline)

                    Spacer()

                    Text(item.planet.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                Text(item.content)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 0)
        }.padding(0)
            .contentShape(Rectangle())
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
