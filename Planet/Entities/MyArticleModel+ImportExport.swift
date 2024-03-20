//
//  MyArticleModel+ImportExport.swift
//  Planet
//

import Foundation
import SwiftUI


extension MyArticleModel {
    @MainActor
    static func importArticles(fromURLs urls: [URL]) async throws {
        guard urls.filter({ $0.lastPathComponent.hasSuffix(".article") }).count > 0 else {
            throw PlanetError.InternalError
        }
        let planets = PlanetStore.shared.myPlanets
        if planets.count > 1 {
            PlanetStore.shared.importingArticleURLs = urls
            PlanetStore.shared.isShowingPlanetPicker = true
        } else if planets.count == 1, let planet = planets.first {
            try importArticles(urls, toPlanet: planet)
        } else {
            throw PlanetError.PlanetNotExistsError
        }
    }

    @MainActor 
    @ViewBuilder
    static func planetPickerView() -> some View {
        let planets = PlanetStore.shared.myPlanets
        VStack(spacing: 0) {
            Text("Choose Planet to Import Articles")
                .font(.headline)
                .frame(height: 44)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.secondary.opacity(0.1))
            ScrollView {
                ForEach(planets, id: \.id) { planet in
                    Button {
                        PlanetStore.shared.isShowingPlanetPicker = false
                        let urls = PlanetStore.shared.importingArticleURLs
                        Task.detached(priority: .userInitiated) {
                            do {
                                try self.importArticles(urls, toPlanet: planet)
                            } catch {
                                debugPrint("failed to import articles: \(error)")
                            }
                        }
                    } label: {
                        VStack {
                            Text(planet.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(planet.about)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .padding(.bottom, 0)
            HStack {
                Button {
                    PlanetStore.shared.isShowingPlanetPicker = false
                    PlanetStore.shared.importingArticleURLs.removeAll()
                } label: {
                    Text("Cancel")
                }
                Spacer()
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
        }
        .frame(width: 360, height: 480)
    }

    func exportArticle() throws {
        let panel = NSOpenPanel()
        panel.message = "Choose Directory to Export Article"
        panel.prompt = "Export"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        let name = self.title.sanitized()
        let exportURL = url.appendingPathComponent("\(name).article")
        if FileManager.default.fileExists(atPath: exportURL.path) {
            throw PlanetError.FileExistsError
        }
        try FileManager.default.copyItem(at: self.publicBasePath, to: exportURL)
        NSWorkspace.shared.activateFileViewerSelecting([exportURL])
    }

    private static func importArticles(_ urls: [URL], toPlanet planet: MyPlanetModel) throws {
        // MARK: TODO: import articles.
    }
}
