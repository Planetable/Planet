//
//  PlanetWriterViewModel.swift
//  Planet
//
//  Created by Kai on 4/28/22.
//

import Foundation
import SwiftUI


class PlanetWriterViewModel: ObservableObject {
    static let shared = PlanetWriterViewModel()
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
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        Task.detached {
            let item = try? await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil)
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                debugPrint("got file: \(url)")
            }
        }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        return true
    }
}
