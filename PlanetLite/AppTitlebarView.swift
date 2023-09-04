//
//  AppTitlebarView.swift
//  Croptop
//

import SwiftUI


struct AppTitlebarView: View {
    @StateObject private var planetStore: PlanetStore
    @State private var title: String = ""
    @State private var subtitle: String = ""
    
    var size: CGSize
    
    init(size: CGSize) {
        self.size = size
        _planetStore = StateObject(wrappedValue: PlanetStore.shared)
    }

    var body: some View {
        HStack {
            if case .myPlanet(let planet) = planetStore.selectedView {
                planet.avatarView(size: 32)
            }
            VStack {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                HStack {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            if case .myPlanet(let planet) = planetStore.selectedView {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(planet.ipns, forType: .string)
                            }
                        }
                    Spacer()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .onReceive(NotificationCenter.default.publisher(for: .updatePlanetLiteWindowTitles)) { n in
            guard let titles = n.object as? [String: String] else { return }
            Task { @MainActor in
                if let theTitle = titles["title"], theTitle != "" {
                    self.title = theTitle
                }
                if let theSubtitle = titles["subtitle"], theSubtitle != "" {
                    self.subtitle = theSubtitle
                } else {
                    self.subtitle = ""
                }
            }
        }
    }
}
