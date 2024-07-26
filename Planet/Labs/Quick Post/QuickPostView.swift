//
//  QuickPostView.swift
//  Planet
//
//  Created by Xin Liu on 4/23/24.
//

import SwiftUI

struct QuickPostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    var body: some View {
        VStack(spacing: 0) {
            // Upper: Avatar | Text Entry
            HStack {
                VStack {
                    if let planet = KeyboardShortcutHelper.shared.activeMyPlanet {
                        planet.avatarView(size: 40)
                            .help(planet.name)
                    }
                    Spacer()
                }
                .frame(width: 40)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.leading, 10)
                .padding(.trailing, 0)

                TextEditor(text: $content)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .lineSpacing(7)
                    .disableAutocorrection(true)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .padding(.leading, 0)
                    .padding(.trailing, 10)
                    .frame(height: 160)
            }
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    content = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)

                Button {
                    // Save content as a new MyArticleModel
                    do {
                        try saveContent()
                    }
                    catch {
                        debugPrint("Failed to save quick post")
                    }
                    content = ""
                    dismiss()
                } label: {
                    Text("Post")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
            }.padding(10)
                .background(Color(NSColor.windowBackgroundColor))
        }.frame(width: 500)
    }

    private func extractTitle(from content: String) -> String {
        let content = content.trim()
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("# ") {
                return line.replacingOccurrences(of: "# ", with: "")
            }
        }
        return ""
    }

    private func extractContent(from content: String) -> String {
        let content = content.trim()
        let lines = content.components(separatedBy: .newlines)
        var result = ""
        var i = 0
        for line in lines {
            if i == 0 {
                if line.hasPrefix("# ") {
                    i += 1
                    continue
                } else {
                    result += "\(line)\n"
                }
            } else {
                result += "\(line)\n"
            }
            i += 1
        }
        return result.trim()
    }

    private func saveContent() throws {
        // Save content as a new MyArticleModel
        guard let planet = KeyboardShortcutHelper.shared.activeMyPlanet else { return }
        let date = Date()
        let article: MyArticleModel = try MyArticleModel.compose(
            link: nil,
            date: date,
            title: extractTitle(from: content),
            content: extractContent(from: content),
            summary: nil,
            planet: planet
        )
        article.attachments = []
        // TODO: Support tags in Quick Post
        article.tags = [:]
        var articles = planet.articles
        articles?.append(article)
        articles?.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
        planet.articles = articles

        do {
            try article.save()
            try article.savePublic()
            try planet.copyTemplateAssets()
            planet.updated = Date()
            try planet.save()

            Task {
                try await planet.savePublic()
                try await planet.publish()
                Task(priority: .background) {
                    await article.prewarm()
                }
            }

            Task { @MainActor in
                PlanetStore.shared.selectedView = .myPlanet(planet)
                PlanetStore.shared.refreshSelectedArticles()
                // wrap it to delay the state change
                if planet.templateName == "Croptop" {
                    Task { @MainActor in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            // Croptop needs a delay here when it loads from the local gateway
                            if PlanetStore.shared.selectedArticle == article {
                                NotificationCenter.default.post(name: .loadArticle, object: nil)
                            }
                            else {
                                PlanetStore.shared.selectedArticle = article
                            }
                            Task(priority: .userInitiated) {
                                NotificationCenter.default.post(
                                    name: .scrollToArticle,
                                    object: article
                                )
                            }
                        }
                    }
                }
                else {
                    Task { @MainActor in
                        if PlanetStore.shared.selectedArticle == article {
                            NotificationCenter.default.post(name: .loadArticle, object: nil)
                        }
                        else {
                            PlanetStore.shared.selectedArticle = article
                        }
                        Task(priority: .userInitiated) {
                            NotificationCenter.default.post(name: .scrollToArticle, object: article)
                        }
                    }
                }
            }
        }
        catch {
            debugPrint("Failed to save quick post")
        }
    }
}

#Preview {
    QuickPostView()
}
