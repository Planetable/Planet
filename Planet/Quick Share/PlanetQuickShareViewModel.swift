//
//  PlanetQuickShareViewModel.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

class PlanetQuickShareViewModel: ObservableObject {
    static let shared = PlanetQuickShareViewModel()

    @Published private(set) var sending: Bool = false
    @Published var myPlanets: [MyPlanetModel] = []
    @Published var selectedPlanetID: UUID = UUID() {
        didSet {
            UserDefaults.standard.set(
                selectedPlanetID.uuidString,
                forKey: .lastSelectedQuickSharePlanetID
            )
        }
    }

    // If you need to add a new feature, you can add a new property here.
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var tags: [String: String] = [:]
    @Published var newTag: String = ""
    @Published var externalLink: String = ""
    @Published var fileURLs: [URL] = []
    @Published private var draft: DraftModel?

    init() {
        if UserDefaults.standard.value(forKey: .lastSelectedQuickSharePlanetID) != nil,
            let uuidString: String = UserDefaults.standard.string(
                forKey: .lastSelectedQuickSharePlanetID
            ), let uuid = UUID(uuidString: uuidString)
        {
            selectedPlanetID = uuid
        }
    }

    func getTargetPlanet() -> MyPlanetModel? {
        return myPlanets.filter({ $0.id == selectedPlanetID }).first
    }

    @MainActor
    func prepareFiles(_ files: [URL]) throws {
        cleanup()
        myPlanets = PlanetStore.shared.myPlanets
        if myPlanets.count == 0 {
            throw PlanetError.PlanetNotExistsError
        }
        else if myPlanets.count == 1 {
            selectedPlanetID = myPlanets.first!.id
        }
        else if let selectedType = PlanetStore.shared.selectedView {
            switch selectedType {
            case .myPlanet(let planet):
                selectedPlanetID = planet.id
            default:
                break
            }
        }
        else if UserDefaults.standard.value(forKey: .lastSelectedQuickSharePlanetID) != nil,
            let uuidString: String = UserDefaults.standard.string(
                forKey: .lastSelectedQuickSharePlanetID
            ), let uuid = UUID(uuidString: uuidString)
        {
            selectedPlanetID = uuid
        }
        title = files.first?.lastPathComponent.sanitized() ?? Date().dateDescription()
        for file in files {
            if file.pathExtension == "tiff" && title == file.lastPathComponent {
                title = file.deletingPathExtension().appendingPathExtension("png").lastPathComponent
            }
        }
        content = ""
        externalLink = ""
        fileURLs = files
    }

    func processPasteItems(_ providers: [NSItemProvider]) {
        Task(priority: .utility) {
            var urls: [URL] = []
            var handled: [NSItemProvider] = []
            for provider in providers {
                // handle .fileURL
                let urlData = try? await provider.loadItem(
                    forTypeIdentifier: UTType.fileURL.identifier
                )
                if let urlData = urlData as? Data {
                    let imageURL =
                        NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                    if isImageFile(url: imageURL) {
                        urls.append(imageURL)
                        handled.append(provider)
                    }
                }
                // handle .image
                if handled.contains(provider) {
                    continue
                }
                let imageData = try? await provider.loadItem(
                    forTypeIdentifier: UTType.image.identifier
                )
                if let imageData = imageData, let data = imageData as? Data,
                    let image = NSImage(data: data)
                {
                    if let pngImageData = image.PNGData {
                        // Write the image as a PNG into temporary and add it to the attachments
                        let fileName = UUID().uuidString + ".png"
                        // Save image to temporary directory
                        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                            fileName
                        )
                        do {
                            try pngImageData.write(to: fileURL)
                            urls.append(fileURL)
                        }
                        catch {
                            debugPrint("Failed to write image to temporary directory: \(error)")
                        }
                    }
                }
            }
            guard urls.count > 0 else { return }
            let processedURLs = urls
            Task { @MainActor in
                do {
                    try PlanetQuickShareViewModel.shared.prepareFiles(processedURLs)
                }
                catch {
                    debugPrint("failed to process paste images: \(error)")
                }
            }
        }
    }

    private func isImageFile(url: URL) -> Bool {
        let imageTypes: [UTType] = [.png, .jpeg, .gif, .tiff, .gif]
        if let fileUTI = UTType(filenameExtension: url.pathExtension),
            imageTypes.contains(fileUTI)
        {
            return true
        }
        return false
    }

    @MainActor
    func send() throws {
        guard let targetPlanet = getTargetPlanet() else { throw PlanetError.PersistenceError }
        guard sending == false else { return }
        sending = true
        defer {
            sending = false
        }
        draft = try DraftModel.create(for: targetPlanet)
        for file in fileURLs {
            try draft?.addAttachment(path: file, type: AttachmentType.from(file))
        }
        draft?.title = title
        var finalContent = ""
        if let attachments = draft?.attachments {
            for attachment in attachments {
                if attachment.type == .image, let markdown = attachment.markdown {
                    finalContent += markdown + "\n\n\n"
                }
            }
        }
        finalContent += content
        draft?.content = finalContent
        if !externalLink.isEmpty {
            draft?.externalLink = externalLink
        }
        if !tags.isEmpty {
            draft?.tags = tags
        }
        try draft?.saveToArticle()
        cleanup()
    }

    func cleanup() {
        try? draft?.delete()
        draft = nil
        title = ""
        content = ""
        externalLink = ""
        fileURLs = []
        sending = false
    }
}

extension NSItemProvider: @unchecked Sendable {}
