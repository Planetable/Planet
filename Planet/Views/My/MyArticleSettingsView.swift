//
//  MyArticleSettingsView.swift
//  Planet
//
//  Created by Xin Liu on 1/9/23.
//

import SwiftUI

struct MyArticleSettingsView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 80

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore

    @ObservedObject var article: MyArticleModel

    @State private var selectedTab: String = "basic"

    @State private var title: String
    @State private var articleType: ArticleType

    init(article: MyArticleModel) {
        self.article = article
        _title = State(wrappedValue: article.title)
        _articleType = State(wrappedValue: article.articleType ?? .blog)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {

                HStack(spacing: 10) {
                    article.planet.smallAvatarAndNameView()
                    Spacer()
                }

                TabView(selection: $selectedTab) {
                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        HStack {
                            HStack {
                                Text("Title")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextField("", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            HStack {
                                Text("Type")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH - 5)
                            // select articleType with radio buttons
                            Picker(
                                selection: $articleType,
                                label: Text("")
                            ) {
                                Text("Blog").tag(ArticleType.blog)
                                Text("Page").tag(ArticleType.page)
                            }.pickerStyle(RadioGroupPickerStyle())
                            Spacer()
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 5)

                            Text("Articles of the Page type are not listed on the blog index page, nor are they included in the RSS feed.")
                                .lineLimit(2)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Basic")
                    }
                    .tag("basic")

                }

                HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(width: 50)
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button {
                        if !title.isEmpty {
                            article.title = title
                        }
                        article.articleType = articleType
                        Task {
                            try article.save()
                            try article.savePublic()
                            NotificationCenter.default.post(name: .loadArticle, object: nil)
                            if let planet = article.planet {
                                try planet.copyTemplateAssets()
                                planet.updated = Date()
                                try planet.save()
                                try planet.savePublic()
                                Task {
                                    try await planet.publish()
                                }
                            }
                        }
                        dismiss()
                    } label: {
                        Text("OK")
                            .frame(width: 50)
                    }
                    .disabled(title.isEmpty)
                }

            }.padding(PlanetUI.SHEET_PADDING)
        }
        .padding(0)
        .frame(width: 520, height: 360, alignment: .top)
        .task {
            title = article.title
        }
    }
}

struct MyArticleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MyArticleSettingsView(article: MyArticleModel.placeholder)
    }
}
