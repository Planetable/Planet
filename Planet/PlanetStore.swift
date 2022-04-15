//
//  PlanetCenter.swift
//  Planet
//
//  Created by Kai on 11/10/21.
//

import Foundation
import Cocoa
import SwiftUI
import Combine


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
            debugPrint("Selected Smart Feed Type: \(selectedSmartFeedType)")
        }
    }
    
    @Published var currentPlanet: Planet! {
        didSet {
            debugPrint("[Current Planet] \(currentPlanet)")
            NotificationCenter.default.post(name: .updateAvatar, object: nil)
        }
    }
    
    @Published var selectedPlanet: String! {
        didSet {
            if let selectedPlanet = selectedPlanet {
                DispatchQueue.global(qos: .utility).async {
                    if let targetPlanet = PlanetDataController.shared.getPlanet(id: UUID(uuidString: selectedPlanet)!) {
                        DispatchQueue.main.async {
                            self.currentPlanet = targetPlanet
                        }
                        return
                    }
                }
            }
            DispatchQueue.main.async {
                self.currentPlanet = nil
            }
        }
    }
    
    @Published var currentArticle: PlanetArticle! {
        didSet {
            debugPrint("[Current Article] \(currentArticle)")
        }
    }

    @Published var selectedArticle: String! {
        didSet {
            if let selectedArticle = selectedArticle {
                if let targetArticle = PlanetDataController.shared.getArticle(id: UUID(uuidString: selectedArticle)!) {
                    DispatchQueue.main.async {
                        self.currentArticle = targetArticle
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                self.currentArticle = nil
            }
        }
    }
    
    @Published var activeWriterID: UUID = .init() {
        didSet {
            DispatchQueue.main.async {
                for w in NSApp.windows {
                    guard w is PlanetWriterWindow else { continue }
                    if (w as! PlanetWriterWindow).draftPlanetID == self.activeWriterID, w.canBecomeKey {
                        w.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
    }
    
    @Published var writerIDs: Set<UUID> = Set() {
        didSet {
            DispatchQueue.main.async {
                for w in NSApp.windows {
                    guard w is PlanetWriterWindow else { continue }
                    if !self.writerIDs.contains((w as! PlanetWriterWindow).draftPlanetID) {
                        w.orderOut(nil)
                    }
                }
            }
        }
    }
}
