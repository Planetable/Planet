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
}


extension PlanetWriterViewModel: DropDelegate {
    func dropEntered(info: DropInfo) {
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let planet = PlanetStore.shared.currentPlanet, planet.isMyPlanet() {
            return DropProposal(operation: .copy)
        }
        return nil
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
            PlanetWriterManager.shared.processUploadings(urls: urls)
        }
        return true
    }
}
