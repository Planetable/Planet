//
//  AppTitlebarView.swift
//  Croptop
//

import SwiftUI
import UserNotifications


struct AppTitlebarView: View {
    @StateObject private var planetStore: PlanetStore
    @State private var title: String = "Croptop"
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
                                copyIPNSAction(fromPlanet: planet)
                            }
                        }
                        .help("Click to copy IPNS")
                    Spacer()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .onReceive(NotificationCenter.default.publisher(for: .updatePlanetLiteWindowTitles)) { n in
            guard let titles = n.object as? [String: String] else { return }
            debugPrint("updating lite title: \(titles) ")
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
    
    private func copyIPNSAction(fromPlanet planet: MyPlanetModel) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(planet.ipns, forType: .string)
        Task(priority: .background) {
            let content = UNMutableNotificationContent()
            content.title = planet.name
            content.subtitle = "IPNS copied."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: planet.ipns,
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
