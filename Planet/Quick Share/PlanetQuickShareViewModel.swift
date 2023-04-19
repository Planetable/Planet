//
//  PlanetQuickShareViewModel.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import Foundation
import SwiftUI


class PlanetQuickShareViewModel: ObservableObject {
    static let shared = PlanetQuickShareViewModel()

    @Published var myPlanets: [MyPlanetModel] = []
    @Published var selectedPlanetID: UUID = UUID() {
        didSet {
            UserDefaults.standard.set(selectedPlanetID.uuidString, forKey: .lastSelectedQuickSharePlanetID)
        }
    }
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var externalLink: String = ""
    @Published var fileURLs: [URL] = []
    @Published private var draft: DraftModel?

    init() {
        if UserDefaults.standard.value(forKey: .lastSelectedQuickSharePlanetID) != nil, let uuidString: String = UserDefaults.standard.string(forKey: .lastSelectedQuickSharePlanetID), let uuid = UUID(uuidString: uuidString) {
            selectedPlanetID = uuid
        }
    }

    func getTargetPlanet() -> MyPlanetModel? {
        return myPlanets.filter({ $0.id == selectedPlanetID }).first
    }

    @MainActor
    func prepareFiles(_ files: [URL]) throws {
        try? draft?.delete()
        draft = nil
        fileURLs = []
        myPlanets = PlanetStore.shared.myPlanets
        if myPlanets.count == 0 {
            throw PlanetError.PlanetNotExistsError
        } else if myPlanets.count == 1 {
            selectedPlanetID = myPlanets.first!.id
        } else if UserDefaults.standard.value(forKey: .lastSelectedQuickSharePlanetID) != nil, let uuidString: String = UserDefaults.standard.string(forKey: .lastSelectedQuickSharePlanetID), let uuid = UUID(uuidString: uuidString) {
            selectedPlanetID = uuid
        } else if let selectedType = PlanetStore.shared.selectedView {
            switch selectedType {
            case .myPlanet(let planet):
                selectedPlanetID = planet.id
            default:
                break
            }
        }
        title = files.first?.lastPathComponent.sanitized() ?? Date().dateDescription()
        content = ""
        externalLink = ""
        fileURLs = files
    }

    @MainActor
    func send() throws {
        guard let targetPlanet = getTargetPlanet() else { throw PlanetError.PersistenceError }
        draft = try DraftModel.create(for: targetPlanet)
        for file in fileURLs {
            try draft?.addAttachment(path: file, type: .image)
        }
        draft?.title = title
        var finalContent = ""
        if let attachments = draft?.attachments {
            for attachment in attachments {
                if let markdown = attachment.markdown {
                    finalContent += markdown + "</br>"
                }
            }
        }
        finalContent += content
        draft?.content = finalContent
        if !externalLink.isEmpty {
            draft?.externalLink = externalLink
        }
        try draft?.saveToArticle()
    }
}
