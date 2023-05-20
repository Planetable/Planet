//
//  AppViewModel.swift
//  PlanetLite
//

import Foundation
import SwiftUI


class AppViewModel: ObservableObject {
    static let shared = AppViewModel()

    @Published var selectedViewName: String? {
        didSet {
            debugPrint("current content view: \(selectedViewName)")
        }
    }
}
