//
//  PlanetImportView.swift
//  Planet
//
//  Created by Kai on 6/20/25.
//

import Foundation
import Cocoa
import SwiftUI


struct PlanetImportView: View {
    enum Step {
        case one
        case two
    }

    @StateObject private var viewModel: PlanetImportViewModel

    @State private var step: Step = .one
    @State private var targetPlanet: MyPlanetModel?

    init() {
        _viewModel = StateObject(wrappedValue: PlanetImportViewModel.shared)
    }

    var body: some View {
        VStack {
            switch step {
            case .one:
                stepOne()
            case .two:
                stepTwo()
            }
        }
        .frame(minWidth: PlanetImportWindow.windowMinWidth, idealWidth: PlanetImportWindow.windowMinWidth, maxWidth: .infinity, minHeight: PlanetImportWindow.windowMinHeight, idealHeight: PlanetImportWindow.windowMinHeight, maxHeight: .infinity)
        .padding(PlanetUI.SHEET_PADDING)
        .sheet(isPresented: $viewModel.showingPreview, onDismiss: {
        }, content: {
            if let previewURL = viewModel.previewURL {
                PlanetImportPreviewView(url: previewURL)
                    .environmentObject(viewModel)
            }
        })
        .task {
            do {
                try await viewModel.prepareToImport()
            } catch {
                failedToImport(error: error)
            }
        }
    }

    // MARK: -

    @ViewBuilder
    private func stepOne() -> some View {
        let isValidating = viewModel.validating.count > 0
        ScrollView {
            ForEach(viewModel.markdownURLs, id: \.self) { url in
                PlanetImportItemView(url: url)
                    .environmentObject(viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        ZStack {
            HStack {
                Spacer()
                Text("Total Files: \(viewModel.markdownURLs.count)")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                Button {
                    viewModel.cancelImport()
                } label: {
                    Text("Cancel")
                }
                Spacer()
                Group {
                    if isValidating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .frame(width: 24)
                    } else {
                        Spacer(minLength: 24)
                    }
                }
                .frame(width: 24)
                Button {
                    Task { @MainActor in
                        viewModel.reloadResources()
                    }
                } label: {
                    Text("Reload")
                }
                .disabled(viewModel.markdownURLs.count == 0 || isValidating)
                Button {
                    step = .two
                } label: {
                    Text("Next")
                }
                .disabled(viewModel.markdownURLs.count == 0 || isValidating)
            }
        }
    }

    @ViewBuilder
    private func stepTwo() -> some View {
        HStack {
            Text("Select a planet to import files")
                .foregroundStyle(Color.secondary)
            Spacer()
        }
        ScrollView {
            ForEach(PlanetStore.shared.myPlanets, id: \.self) { planet in
                HStack {
                    planet.avatarView(size: 40)
                    Text(planet.name)
                    Spacer()
                    if targetPlanet == planet {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    targetPlanet = planet
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        HStack {
            Button {
                step = .one
            } label: {
                Text("Back")
            }
            Spacer()
            Button {
                importToPlanet()
            } label: {
                Text("Import")
            }
            .buttonStyle(.borderedProminent)
            .disabled(targetPlanet == nil)
        }
    }

    private func failedToImport(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Import Files"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        viewModel.cancelImport()
    }

    private func importToPlanet() {
        defer {
            viewModel.cancelImport()
        }

        guard let targetPlanet else {
            PlanetImportViewModel.logger.info(.init(stringLiteral: "Target planet not found, abort importing."))
            return
        }

        PlanetImportViewModel.logger.info(.init(stringLiteral: "About to import to planet: \(targetPlanet.name)"))

        var importArticles: [MyArticleModel] = []
        for url in viewModel.markdownURLs {
            PlanetImportViewModel.logger.info(.init(stringLiteral: "Process and import markdown: \(url) ..."))
            do {
                let title = try viewModel.titleFromMarkdown(url)
                let date = try viewModel.dateFromMarkdown(url)
                let content = try viewModel.contentFromMarkdown(url)
                let article = try MyArticleModel.compose(
                    link: nil,
                    date: date,
                    title: title,
                    content: content,
                    summary: nil,
                    planet: targetPlanet
                )
                //MARK: TODO: add attachments
                article.attachments = []
                article.tags = [:]
                importArticles.append(article)
            } catch {
                PlanetImportViewModel.logger.info(.init(stringLiteral: "Skip markdown url: \(url), error: \(error)"))
            }
        }

        guard importArticles.count > 0 else {
            PlanetImportViewModel.logger.info(.init(stringLiteral: "Markdown files not found, abort importing."))
            return
        }

        var articles = targetPlanet.articles
        articles?.append(contentsOf: importArticles)
        articles?.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
        targetPlanet.articles = articles

        for article in importArticles {
            do {
                try article.save()
                try article.savePublic()
            } catch {
                PlanetImportViewModel.logger.info(.init(stringLiteral: "Failed to import article: \(article.title), error: \(error)"))
            }
        }

        do {
            try targetPlanet.copyTemplateAssets()
            targetPlanet.updated = Date()
            try targetPlanet.save()
            Task(priority: .userInitiated) {
                try await targetPlanet.savePublic()
                try await targetPlanet.publish()
            }
        } catch {
            PlanetImportViewModel.logger.info(.init(stringLiteral: "Failed to save target planet, error: \(error)"))
        }

        Task { @MainActor in
            PlanetStore.shared.selectedView = .myPlanet(targetPlanet)
            PlanetStore.shared.refreshSelectedArticles()
        }

        PlanetImportViewModel.logger.info(.init(stringLiteral: "Imported markdown files."))
    }
}
