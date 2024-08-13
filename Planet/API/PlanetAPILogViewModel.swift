//
//  PlanetAPILogViewModel.swift
//  Planet
//

import Foundation
import SwiftUI


class PlanetAPILogViewModel: ObservableObject {
    static let shared = PlanetAPILogViewModel()
    static let maxLength: Int = 2000

    @Published private(set) var logs: [String] = []

    init() {
    }

    @MainActor
    func addLog(_ log: String) {
        logs.insert(log, at: 0)
        if logs.count > Self.maxLength {
            logs = Array(logs.suffix(Self.maxLength))
        }
    }
}
