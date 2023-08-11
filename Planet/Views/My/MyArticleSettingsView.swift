//
//  MyArticleSettingsView.swift
//  Planet
//
//  Created by Xin Liu on 1/9/23.
//

import SwiftUI
import WrappingHStack

struct MyArticleSettingsView: View {
    let MESSAGE_SLUG_REQUIREMENT =
        "The slug is the part of the URL that identifies the article. It should be unique and contain only lowercased letters, numbers, and hyphens."
    let MESSAGE_EXTERNAL_LINK =
        "If you want this article to redirect to an external link, enter the URL here."

    let CONTROL_CAPTION_WIDTH: CGFloat = 80

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore

    @ObservedObject var article: MyArticleModel

    @State private var selectedTab: String = "basic"

    @State private var title: String
    @State private var articleType: ArticleType
    @State private var slug: String
    @State private var externalLink: String

    @State private var tags: [String: String] = [:]
    @State private var newTag: String = ""

    @State private var isIncludedInNavigation: Bool
    @State private var navigationWeight: String

    init(article: MyArticleModel) {
        self.article = article
        _title = State(wrappedValue: article.title)
        _articleType = State(wrappedValue: article.articleType ?? .blog)
        _slug = State(wrappedValue: article.slug ?? "")
        _externalLink = State(wrappedValue: article.externalLink ?? "")
        _isIncludedInNavigation = State(wrappedValue: article.isIncludedInNavigation ?? false)
        _navigationWeight = State(wrappedValue: article.navigationWeight?.stringValue() ?? "1")
        _tags = State(wrappedValue: article.tags ?? [:])
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
                            .frame(width: CONTROL_CAPTION_WIDTH + 40)

                            TextField("", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }

                        slugView()

                        HStack {
                            HStack {
                                Text("External Link")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 40)

                            TextField("", text: $externalLink)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 50)

                            Text(MESSAGE_EXTERNAL_LINK)
                                .lineLimit(3)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack {
                            HStack {
                                Text("Type")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH - 5 + 40)
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
                            .frame(width: CONTROL_CAPTION_WIDTH + 5 + 40)

                            Text(
                                "Articles of the Page type are not listed on the blog index page, nor are they included in the RSS feed."
                            )
                            .lineLimit(2)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        tagsView()

                        siteNavigationView()
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
                        if verifyUserInput() > 0 {
                            return
                        }
                        if !title.isEmpty {
                            article.title = title
                        }
                        var previousSlug = article.slug
                        var nextSlug = slug
                        var slugChanged = false
                        if !slug.isEmpty {
                            if slug.count == 0 {
                                if article.slug != slug {
                                    article.slug = nil
                                    slugChanged = true
                                }
                            }
                            else {
                                if article.slug != slug {
                                    article.slug = slug
                                    slugChanged = true
                                }
                            }
                        }
                        else {
                            if article.slug != slug {
                                article.slug = nil
                                slugChanged = true
                            }
                        }
                        if !externalLink.isEmpty {
                            article.externalLink = externalLink
                        }
                        else {
                            article.externalLink = nil
                        }
                        if let articleSlug = article.slug, articleSlug.count > 0 {
                            article.link = "/\(articleSlug)/"
                        } else {
                            article.link = "/\(article.id.uuidString)/"
                        }
                        article.articleType = articleType
                        article.isIncludedInNavigation = isIncludedInNavigation
                        article.navigationWeight = Int(navigationWeight)
                        article.tags = tags
                        Task {
                            try article.save()
                            if let previousSlug = previousSlug, slugChanged {
                                article.removeSlug(previousSlug)
                            }
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
        .frame(width: 520, height: nil, alignment: .top)
    }

    @ViewBuilder
    private func slugView() -> some View {
        HStack {
            HStack {
                Text("Slug")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 40)

            TextField("", text: $slug)
                .textFieldStyle(.roundedBorder)
        }

        HStack {
            HStack {
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 50)

            Text(MESSAGE_SLUG_REQUIREMENT)
                .lineLimit(3)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func tagsView() -> some View {
        Divider()

        HStack {
            HStack {
                Text("Tags")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 40)

            // Tag capsules
            WrappingHStack(tags.values.sorted(), id: \.self, alignment: .leading, spacing: .constant(2), lineSpacing: 4) { tag in
                TagView(tag: tag)
                    .onTapGesture {
                        tags.removeValue(forKey: tag.normalizedTag())
                    }
            }
        }

        HStack {
            HStack {
                Text("Add a Tag")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 40)

            TextField("", text: $newTag)
                .textFieldStyle(.roundedBorder)

            Button {
                addTag()
            } label: {
                Text("Add")
            }
        }
    }

    private func addTag() {
        var aTag = newTag.trim()
        var normalizedTag = aTag.normalizedTag()
        if normalizedTag.count > 0 {
            if tags.keys.contains(aTag) {
                // tag already exists
                return
            }
            tags[normalizedTag] = aTag
            newTag = ""
        }
    }

    @ViewBuilder
    private func siteNavigationView() -> some View {
        Divider()

        HStack {
            HStack {
                Spacer()
            }.frame(width: CONTROL_CAPTION_WIDTH + 40 + 10)
            Toggle("Include in Site Navigation", isOn: $isIncludedInNavigation)
                .toggleStyle(.checkbox)
                .frame(alignment: .leading)
            Spacer()
        }

        HStack {
            HStack {
                Text("Navigation Weight")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 40)

            TextField("Please enter an integer", text: $navigationWeight)
                .textFieldStyle(.roundedBorder)
        }

        HStack {
            HStack {
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 5 + 40)

            Text(
                "Please input an integer for sorting, entries with smaller numbers will be ranked first."
            )
            .lineLimit(2)
            .font(.footnote)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension MyArticleSettingsView {
    func verifyUserInput() -> Int {
        var errors = 0
        // if slug is not empty, it should only contain letters, numbers, and hyphens
        // check slug with a regular expression
        if !slug.isEmpty {
            let regex = try! NSRegularExpression(pattern: "^[a-z0-9-]+$")
            let range = NSRange(location: 0, length: slug.utf16.count)
            let matches = regex.matches(in: slug, options: [], range: range)
            if matches.count == 0 {
                // slug is not valid
                debugPrint("Provided slug is not valid: \(slug)")
                errors = errors + 1

                let alert = NSAlert()
                alert.messageText = "Article Slug Issue"
                alert.informativeText = MESSAGE_SLUG_REQUIREMENT
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            else {
                // check for conflict in planet.articles except for the current article
                if let planet = article.planet {
                    for article in planet.articles {
                        if article.slug == slug && article.id != self.article.id {
                            debugPrint("Provided slug is not unique: \(slug)")
                            errors = errors + 1

                            let alert = NSAlert()
                            alert.messageText = "Article Slug Issue"
                            alert.informativeText =
                                "The slug is already used by \(article.title) (ID: \(article.id)). Please choose a different slug."
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                            break
                        }
                    }
                }
            }
        }
        return errors
    }
}

struct TagView: View {
    let tag: String

    var body: some View {
        HStack {
            Text(tag)
                .font(.footnote)
                .foregroundColor(.secondary)
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .background(Color("BorderColor"))
        .cornerRadius(8)
    }
}

struct MyArticleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MyArticleSettingsView(article: MyArticleModel.placeholder)
    }
}
