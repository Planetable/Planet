//
//  PlanetStatusViewModel.swift
//  Planet
//
//  Created by Kai on 4/15/22.
//

import Foundation
import SwiftUI
import Combine


class PlanetStatusViewModel: ObservableObject {
    static let shared = PlanetStatusViewModel()
    @Published var daemonIsOnline: Bool = false
    @Published var peersCount: Int = 0
    @Published var publishingPlanets: Set<UUID> = Set()
    @Published var updatingPlanets: Set<UUID> = Set()
    @Published var lastPublishedDates: [UUID: Date] = [:]
    @Published var lastUpdatedDates: [UUID: Date] = [:]
}
