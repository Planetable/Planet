//
//  AvatarPickerView.swift
//  Planet
//
//  Created by Xin Liu on 7/27/23.
//

import SwiftUI

enum AvatarCategory: String, CaseIterable {
    case nostalgia = "Nostalgia"
    case monochrom = "Monochrom"
    case pixelPlanet = "Pixel Planet"

    var id: String { rawValue }

    var jsonFile: String {
        switch self {
        case .nostalgia:
            return "NSTG"
        case .monochrom:
            return "MNCR"
        case .pixelPlanet:
            return "PP"
        }
    }
}

struct AvatarPickerView: View {
    @EnvironmentObject var store: PlanetStore
    @Binding var selection: AvatarCategory?
    @Environment(\.dismiss) var dismiss
    @State var avatars: [String: String]?
    @State var selectedAvatar: NSImage?
    @State var avatarChanged: Bool = false
    @State private var randomSelectedAvatarKey: String?
    @State private var highlightedItems: Set<String> = []

    private func loadAvatars(category: AvatarCategory) -> [String: String]? {
        debugPrint("Loading Avatar category: \(category)")
        if let metadataFile = Bundle.main.url(forResource: category.jsonFile, withExtension: "json")
        {
            do {
                let data = try Data(contentsOf: metadataFile)
                let decoder = JSONDecoder()
                let metadata = try decoder.decode([String: String].self, from: data)
                debugPrint("Loaded avatar metadata: \(metadata)")
                return metadata
            }
            catch {
                debugPrint("Failed to load avatar metadata: \(error)")
            }
        }
        else {
            debugPrint("Avatar metadata \(category.jsonFile).json not found")
        }
        return nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(AvatarCategory.allCases, id: \.self) { aCategory in
                        Text(aCategory.rawValue)
                    }
                }

                Spacer()

                if case .myPlanet(let planet) = store.selectedView {
                    ArtworkView(
                        image: selectedAvatar,
                        planetNameInitials: planet.nameInitials,
                        planetID: planet.id,
                        cornerRadius: 72,
                        size: CGSize(width: 144, height: 144),
                        uploadAction: { url in
                            do {
                                selectedAvatar = NSImage(contentsOf: url)
                                avatarChanged = true
                            }
                            catch {
                                debugPrint("failed to upload planet avatar: \(error)")
                            }
                        },
                        deleteAction: {
                            do {
                                selectedAvatar = nil
                            }
                            catch {
                                debugPrint("failed to remove planet avatar: \(error)")
                            }
                        }
                    )
                    .padding(.bottom, 20)
                }
            }
            .frame(width: 200)

            VStack(spacing: 0) {
                if let avatars = avatars, let keys = Array(avatars.keys) as? [String] {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(), GridItem(), GridItem()],
                                alignment: .center
                            ) {
                                ForEach(keys.sorted(), id: \.self) { aKey in
                                    VStack {
                                        let isAnimation: Bool = highlightedItems.contains(aKey)
                                        Image(aKey)
                                            .interpolation(.high)
                                            .resizable()
                                            .frame(width: 64, height: 64)
                                            .cornerRadius(32)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 32)
                                                    .stroke(isAnimation ? Color.accentColor : Color("BorderColor"), lineWidth: isAnimation ? 4 : 1)
                                            )
                                            .padding(.top, 16)
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 8)
                                            .scaleEffect(isAnimation ? 1.05 : 1.0)
                                            .animation(.linear(duration: 0.3), value: highlightedItems)

                                        Text(avatars[aKey] ?? "")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    .id(aKey)
                                    .onTapGesture {
                                        debugPrint("Tapped on avatar: \(aKey)")
                                        if case .myPlanet(let planet) = store.selectedView {
                                            debugPrint("About to set planet avatar to \(aKey)")
                                            do {
                                                let image = NSImage(named: aKey)
                                                if let image = image, let avatarURL = image.temporaryURL
                                                {
                                                    selectedAvatar = image
                                                    avatarChanged = true
                                                    debugPrint("Set planet avatar to \(aKey)")
                                                }
                                            }
                                            catch {
                                                debugPrint("failed to update planet avatar: \(error)")
                                            }
                                        }
                                        else {
                                            debugPrint("Cannot set planet avatar")
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: randomSelectedAvatarKey) { newValue in
                            guard let newValue else { return }
                            Task { @MainActor in
                                withAnimation(.linear(duration: 0.25)) {
                                    proxy.scrollTo(newValue)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.highlightedItems.insert(newValue)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.highlightedItems.remove(newValue)
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button {
                        randomPick()
                    } label: {
                        Text("Random Pick")
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(minWidth: PlanetUI.BUTTON_MIN_WIDTH_SHORT)
                    }

                    Button {
                        if let avatar = selectedAvatar, let avatarURL = avatar.temporaryURL,
                            case .myPlanet(let planet) = store.selectedView
                        {
                            try? planet.updateAvatar(path: avatarURL)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                NotificationCenter.default.post(name: .publishMyPlanet, object: planet)
                            }
                            dismiss()
                        }
                    } label: {
                        Text("Save")
                            .frame(minWidth: PlanetUI.BUTTON_MIN_WIDTH_SHORT)
                    }
                    .disabled(!avatarChanged)
                }
                .padding(16)
            }
        }
        .frame(width: 600, height: 400)
        .onAppear {
            if selection == nil {
                selection = .nostalgia
            }
            if case .myPlanet(let planet) = store.selectedView {
                selectedAvatar = planet.avatar
            }
            if let category = selection {
                avatars = loadAvatars(category: category)
            }
        }
        .onChange(of: selection) { newValue in
            if let category = newValue {
                avatars = loadAvatars(category: category)
            }
        }
    }

    private func randomPick() {
        if let avatars = avatars, let keys = Array(avatars.keys) as? [String] {
            let randomIndex = Int.random(in: 0..<keys.count)
            let randomKey = keys[randomIndex]
            debugPrint("Randomly picked avatar: \(randomKey)")
            let image = NSImage(named: randomKey)
            if let image = image, let avatarURL = image.temporaryURL {
                selectedAvatar = image
                avatarChanged = true
                debugPrint("Set planet avatar to \(randomKey)")
                Task { @MainActor in
                    self.randomSelectedAvatarKey = randomKey
                }
            }
        }
    }
}
