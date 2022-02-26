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
    
    let timer = Timer.publish(every: 5, tolerance: 1, on: .current, in: .common).autoconnect()

    @Published var daemonIsOnline: Bool = false
    @Published var peersCount: Int = 0
    
    @Published var isCreatingPlanet: Bool = false
    @Published var isEditingPlanet: Bool = false
    @Published var isFollowingPlanet: Bool = false
    @Published var isShowingPlanetInfo: Bool = false
    
    @Published var isFailedAlert: Bool = false
    @Published var failedAlertTitle: String = ""
    @Published var failedAlertMessage: String = ""
    
    @Published var templatePaths: [URL] = []
    
    @Published var publishingPlanets: Set<UUID> = Set()
    @Published var updatingPlanets: Set<UUID> = Set()
    
    @Published var lastPublishedDates: [UUID: Date] = [:]
    @Published var lastUpdatedDates: [UUID: Date] = [:]

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
                DispatchQueue.global(qos: .utility).async {
                    if let targetArticle = PlanetDataController.shared.getArticle(id: UUID(uuidString: selectedArticle)!) {
                        DispatchQueue.main.async {
                            self.currentArticle = targetArticle
                        }
                        return
                    }
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
                    if (w as! PlanetWriterWindow).articleID == self.activeWriterID, w.canBecomeKey {
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
                    if !self.writerIDs.contains((w as! PlanetWriterWindow).articleID) {
                        w.orderOut(nil)
                    }
                }
            }
        }
    }
}
