//
//  PlanetAPIConsoleViewModel.swift
//  Planet
//

import Foundation
import SwiftUI


class PlanetAPIConsoleViewModel: ObservableObject {
    static let shared = PlanetAPIConsoleViewModel()
    static let maxLength: Int = 2000
    static let baseFontKey: String = "APIConsoleBaseFontSizeKey"

    @Published var isShowingConsoleWindow = false
    @Published private(set) var baseFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(baseFontSize, forKey: Self.baseFontKey)
        }
    }

    @Published private(set) var logs: [
        (
            timestamp: Date,
            statusCode: UInt,
            requestURL: String,
            errorDescription: String
        )
    ] = []

    init() {
        var fontSize = CGFloat(UserDefaults.standard.float(forKey: Self.baseFontKey))
        if fontSize == 0 {
            fontSize = 12
        }
        baseFontSize = fontSize
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
    
    @MainActor
    func decreaseFontSize() {
        if baseFontSize > 9 {
            baseFontSize -= 1
        }
    }
    
    @MainActor
    func increaseFontSize() {
        baseFontSize += 1
    }
    
    @MainActor
    func resetFontSize() {
        baseFontSize = 12
    }
    
    @MainActor
    func clearLogs() {
        logs.removeAll()
    }
}
