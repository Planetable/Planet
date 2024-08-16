//
//  PlanetAPIConsoleViewModel.swift
//  Planet
//

import Foundation
import SwiftUI


class PlanetAPIConsoleViewModel: ObservableObject {
    static let shared = PlanetAPIConsoleViewModel()
    static let maxLength: Int = 2000

    @Published var isShowingConsoleWindow = false

    @Published private(set) var logs: [
        (
            timestamp: Date,
            statusCode: UInt,
            requestURL: String,
            errorDescription: String
        )
    ] = []

    init() {
    }

    @MainActor
    func addLog(statusCode: UInt, requestURL: String, errorDescription: String = "") {
        let now = Date()
        let logEntry = (timestamp: now, statusCode: statusCode, requestURL: requestURL, errorDescription: errorDescription)
        logs.append(logEntry)
        if logs.count > Self.maxLength {
            logs = Array(logs.suffix(Self.maxLength))
        }
    }
}
