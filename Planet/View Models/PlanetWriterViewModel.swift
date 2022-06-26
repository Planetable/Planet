//
//  PlanetWriterViewModel.swift
//  Planet
//
//  Created by Kai on 4/28/22.
//

import Foundation
import SwiftUI


private struct PlanetWriterDraggingValidation {
    let sequenceNumber: Int
    let offsetX: CGFloat
    let offsetY: CGFloat

    static func ==(lhs: PlanetWriterDraggingValidation, rhs: PlanetWriterDraggingValidation) -> Bool {
        return (lhs.sequenceNumber == rhs.sequenceNumber && lhs.offsetX == rhs.offsetX && lhs.offsetY == rhs.offsetY)
    }
}


class PlanetWriterViewModel: ObservableObject {
    static let shared = PlanetWriterViewModel()

    @Published private(set) var uploadings: [UUID: Set<URL>] = [:]
    
    @Published private(set) var attachedVideo: [UUID: URL?] = [:]

    // [ArticleUUID: PlanetUUID]
    // ArticleUUID == PlanetUUID: Creating Article
    // ArticleUUID != PlanetUUID: Editing Article
    @Published private(set) var editings: [UUID: UUID] = [:]

    @Published private(set) var activeTargetID: UUID = UUID()

    private var draggingInfo: [Int: PlanetWriterDraggingValidation] = [:]

    @MainActor
    func updateDraggingInfo(sequenceNumber: Int, location: NSPoint) {
        let validation = PlanetWriterDraggingValidation(sequenceNumber: sequenceNumber, offsetX: location.x, offsetY: location.y)
        draggingInfo[sequenceNumber] = validation
    }

    @MainActor
    func validateDragginInfo(sequenceNumber: Int, location: NSPoint) -> Bool {
        if let validation = draggingInfo[sequenceNumber] {
            let current = PlanetWriterDraggingValidation(sequenceNumber: sequenceNumber, offsetX: location.x, offsetY: location.y)
            return validation == current
        }
        return true
    }

    @MainActor
    func updateUploadings(articleID: UUID, urls: [URL]) async {
        if uploadings[articleID] == nil {
            uploadings[articleID] = Set<URL>()
        }
        for u in urls {
            uploadings[articleID]?.insert(u)
        }
    }

    @MainActor
    func removeUploadings(articleID: UUID, url: URL) {
        uploadings[articleID]?.remove(url)
    }

    @MainActor
    func removeAllUploadings(articleID: UUID) {
        uploadings[articleID]?.removeAll()
    }
    
    @MainActor
    func attachVideo(articleID: UUID, url: URL) async {
        attachedVideo[articleID] = url
        debugPrint("Attach Video: attached \(attachedVideo)")
    }
    
    @MainActor
    func removeAttachedVideo(articleID: UUID) {
        attachedVideo[articleID] = nil
    }

    @MainActor
    func updateEditings(articleID: UUID, planetID: UUID) {
        if editings[articleID] == nil {
            editings[articleID] = UUID()
        }
        editings[articleID] = planetID
    }

    @MainActor
    func removeEditings(articleID: UUID) {
        editings.removeValue(forKey: articleID)
    }

    @MainActor
    func updateActiveID(articleID: UUID) {
        guard activeTargetID != articleID else { return }
        activeTargetID = articleID
    }
}


extension PlanetWriterViewModel: DropDelegate {
    func dropEntered(info: DropInfo) {
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard let _ = info.itemProviders(for: [.fileURL]).first else { return false }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        let supportedExtensions: [String] = ["png", "jpeg", "gif", "tiff", "jpg"]
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                let item = try? await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil)
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil), supportedExtensions.contains(url.pathExtension) {
                    urls.append(url)
                }
            }
            if let activeID = editings[activeTargetID] {
                PlanetWriterManager.shared.processUploadings(urls: urls, targetID: activeTargetID, inEditMode: activeID != activeTargetID)
            }
        }
        return true
    }
}
