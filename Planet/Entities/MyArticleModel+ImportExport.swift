//
//  MyArticleModel+ImportExport.swift
//  Planet
//

import Foundation
import SwiftUI


extension MyArticleModel {
    @MainActor
    static func importArticles(fromURLs urls: [URL], isCroptopData: Bool = false) async throws {
        let suffix = isCroptopData ? ".post" : ".article"
        let articleURLs: [URL] = urls.filter({ $0.lastPathComponent.hasSuffix(suffix) })
        guard articleURLs.count > 0 else {
            throw PlanetError.InternalError
        }
        let planets = PlanetStore.shared.myPlanets
        if planets.count > 1 {
            PlanetStore.shared.importingArticleURLs = articleURLs
            PlanetStore.shared.isShowingPlanetPicker = true
        } else if planets.count == 1, let planet = planets.first {
            try await importArticles(articleURLs, toPlanet: planet, isCroptopData: isCroptopData)
        } else {
            throw PlanetError.PlanetNotExistsError
        }
    }

    @MainActor 
    @ViewBuilder
    static func planetPickerView() -> some View {
        let isCroptopData = PlanetStore.shared.app == .lite
        let planets = PlanetStore.shared.myPlanets
        VStack(spacing: 0) {
            let title = isCroptopData ? "Choose Site to Import Posts" : "Choose Planet to Import Articles"
            Text(title)
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
                                try await self.importArticles(urls, toPlanet: planet, isCroptopData: isCroptopData)
                            } catch {
                                let title = isCroptopData ? "Failed to Import Posts" : "Failed to Import Articles"
                                Task { @MainActor in
                                    PlanetStore.shared.alert(title: title, message: error.localizedDescription)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            planet.avatarView(size: 36)
                            VStack {
                                Text(planet.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if planet.about.count > 0 {
                                    Text(planet.about)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(Color.secondary)
                                } else {
                                    Spacer()
                                }
                            }
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

    func exportArticle(isCroptopData: Bool = false) throws {
        let panel = NSOpenPanel()
        let exportName = isCroptopData ? "Post" : "Article"
        panel.message = "Choose Directory to Export \(exportName)"
        panel.prompt = "Export"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        let name = self.title.sanitized()
        let suffix = isCroptopData ? ".post" : ".article"
        let exportURL = url.appendingPathComponent("\(name)\(suffix)")
        if FileManager.default.fileExists(atPath: exportURL.path) {
            throw PlanetError.FileExistsError
        }
        try FileManager.default.copyItem(at: self.publicBasePath, to: exportURL)
        NSWorkspace.shared.activateFileViewerSelecting([exportURL])
    }

    func airDropArticle(isCroptopData: Bool = false) throws {
        guard let service: NSSharingService = NSSharingService(named: .sendViaAirDrop) else {
            throw PlanetError.ServiceAirDropNotExistsError
        }
        let url = URLUtils.temporaryPath
        let name = self.title.sanitized()
        let suffix = isCroptopData ? ".post" : ".article"
        let exportURL = url.appendingPathComponent("\(name)\(suffix)")
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }
        try FileManager.default.copyItem(at: self.publicBasePath, to: exportURL)
        if service.canPerform(withItems: [exportURL]) {
            service.perform(withItems: [exportURL])
        } else {
            throw PlanetError.ServiceAirDropNotExistsError
        }
    }

    private static func importArticles(_ urls: [URL], toPlanet planet: MyPlanetModel, isCroptopData: Bool = false) async throws {
        guard planet.isPublishing == false else {
            throw PlanetError.ImportPlanetArticlePublishingError
        }
        var selectingArticle: MyArticleModel?
        var planetArticles: [MyArticleModel] = planet.articles
        let decoder = JSONDecoder()
        for url in urls {
            let articleInfoPath = url.appendingPathComponent("article.json")
            let articleData = try Data(contentsOf: articleInfoPath)
            let articleToImport = try decoder.decode(MyArticleModel.self, from: articleData)
            // Verify importing article is not duplicated
            if planet.articles.first(where: { $0.title == articleToImport.title && $0.content == articleToImport.content }) != nil {
                throw PlanetError.ImportPlanetArticleError
            }
            // Verify importing article has attachments
            if let attachments = articleToImport.attachments {
                for attachment in attachments {
                    let attachmentURL = url.appendingPathComponent(attachment)
                    guard FileManager.default.fileExists(atPath: attachmentURL.path) else {
                        throw PlanetError.ImportPlanetArticleError
                    }
                }
            }
            let newArticleUUID = UUID()
            let newArticle = MyArticleModel(
                id: newArticleUUID,
                link: newArticleUUID.uuidString,
                slug: articleToImport.slug,
                heroImage: articleToImport.heroImage,
                externalLink: articleToImport.externalLink,
                title: articleToImport.title,
                content: articleToImport.content,
                contentRendered: articleToImport.contentRendered,
                summary: articleToImport.summary,
                created: articleToImport.created,
                starred: articleToImport.starred,
                starType: articleToImport.starType,
                videoFilename: articleToImport.videoFilename,
                audioFilename: articleToImport.audioFilename,
                attachments: articleToImport.attachments,
                isIncludedInNavigation: articleToImport.isIncludedInNavigation,
                navigationWeight: articleToImport.navigationWeight
            )
            newArticle.planet = planet
            newArticle.pinned = articleToImport.pinned
            try FileManager.default.copyItem(at: url, to: newArticle.publicBasePath)
            try newArticle.save()
            try newArticle.savePublic()
            if isCroptopData {
                let heroGridPath = newArticle.publicBasePath.appendingPathComponent(
                        "_grid.png",
                        isDirectory: false
                    )
                if FileManager.default.fileExists(atPath: heroGridPath.path) {
                    newArticle.hasHeroGrid = true
                }
            }
            planetArticles.append(newArticle)
            selectingArticle = newArticle
        }
        planetArticles.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
        let updatedPlanetArticles = planetArticles
        await MainActor.run {
            planet.articles = updatedPlanetArticles
        }
        try planet.save()
        try await planet.savePublic()
        let updatedPlanet = try MyPlanetModel.load(from: planet.basePath)
        await MainActor.run {
            PlanetStore.shared.myPlanets = PlanetStore.shared.myPlanets.map { p in
                if p.id == planet.id {
                    return updatedPlanet
                }
                return p
            }
            PlanetStore.shared.selectedView = .myPlanet(updatedPlanet)
            withAnimation {
                PlanetStore.shared.selectedArticleList = updatedPlanet.articles
            }
        }
        if urls.count == 1, let selectingArticle {
            await MainActor.run {
                PlanetStore.shared.selectedArticle = selectingArticle
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                if selectingArticle.pinned != nil {
                    NotificationCenter.default.post(name: .scrollToTopArticleList, object: nil)
                } else {
                    NotificationCenter.default.post(name: .scrollToArticle, object: selectingArticle)
                }
            }
        }
        try await planet.publish()
    }
}
