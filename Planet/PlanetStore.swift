//
//  PlanetCenter.swift
//  Planet
//
//  Created by Kai on 11/10/21.
//

import Foundation
import Cocoa
import SwiftUI


@MainActor
class PlanetStore: ObservableObject {
    static let shared: PlanetStore = .init()

    let indicatorTimer = Timer.publish(every: 1.25, tolerance: 0.25, on: .current, in: .default).autoconnect()

    @Published var isCreatingPlanet: Bool = false
    @Published var isEditingPlanet: Bool = false
    @Published var isFollowingPlanet: Bool = false
    @Published var isShowingPlanetInfo: Bool = false
    @Published var isImportingPlanet: Bool = false
    @Published var isExportingPlanet: Bool = false
    @Published var isAlert: Bool = false

    @Published var selectedSmartFeedType: SmartFeedType? {
        didSet {
            debugPrint("Selected Smart Feed Type: \(String(describing: selectedSmartFeedType))")
        }
    }

    @Published var currentPlanet: Planet? {
        didSet {
            debugPrint("[Current Planet] \(String(describing: currentPlanet))")
            NotificationCenter.default.post(name: .updateAvatar, object: nil)
        }
    }

    @Published var pendingFollowingPlanet: Planet?

    @Published var currentArticle: PlanetArticle? {
        didSet {
            debugPrint("[Current Article] \(String(describing: currentArticle))")
        }
    }

    @Published var activeWriterID: UUID = .init() {
        didSet {
            for w in NSApp.windows {
                if let w = w as? PlanetWriterWindow, w.writerID == activeWriterID, w.canBecomeKey {
                    w.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    @Published var writerIDs: Set<UUID> = Set() {
        didSet {
            for w in NSApp.windows {
                if let w = w as? PlanetWriterWindow, !writerIDs.contains(w.writerID) {
                    w.orderOut(nil)
                }
            }
        }
    }
}
