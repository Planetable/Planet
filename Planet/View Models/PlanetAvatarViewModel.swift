//
//  PlanetAvatarViewModel.swift
//  Planet
//
//  Created by Kai on 5/2/22.
//

import Foundation
import SwiftUI


class PlanetAvatarViewModel: ObservableObject {
    static let shared = PlanetAvatarViewModel()
}


extension PlanetAvatarViewModel: DropDelegate {
    func dropEntered(info: DropInfo) {
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let planet = PlanetStore.shared.currentPlanet, planet.isMyPlanet() {
            return DropProposal(operation: .copy)
        }
        return nil
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard let _ = info.itemProviders(for: [.fileURL]).first else { return false }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        let supportedExtensions: [String] = ["png", "jpeg", "gif", "tiff", "jpg"]
        Task.detached {
            let item = try? await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil)
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil), supportedExtensions.contains(url.pathExtension), let planet = await PlanetStore.shared.currentPlanet, planet.isMyPlanet(), let img = NSImage(contentsOf: url) {
                let targetImage = PlanetManager.shared.resizedAvatarImage(image: img)
                planet.updateAvatar(image: targetImage)
            }
        }
        return true
    }
}
