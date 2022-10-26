//
//  ArtworkView.swift
//  Planet
//
//  Created by Kai on 10/26/22.
//

import SwiftUI
import UniformTypeIdentifiers


enum PlanetArtworkType {
    case avatar
    case podcastCoverArt
}


struct ArtworkView: View {
    @ObservedObject var planet: MyPlanetModel
    @StateObject var dragAndDrop: ArtworkDragAndDrop

    var artworkType: PlanetArtworkType
    var cornerRadius: CGFloat
    var size: CGSize

    @State private var isHovering: Bool = false

    init(planet: MyPlanetModel, artworkType: PlanetArtworkType, cornerRadius: CGFloat = 0, size: CGSize = .zero) {
        self.planet = planet
        self.artworkType = artworkType
        self.cornerRadius = cornerRadius
        self.size = size
        self._dragAndDrop = StateObject(wrappedValue: ArtworkDragAndDrop(planet: planet, artworkType: artworkType))
    }

    var body: some View {
        VStack {
            if let image = getArtworkImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height, alignment: .center)
                    .cornerRadius(cornerRadius)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            .overlay {
                                if isHovering {
                                    editLabel()
                                }
                            }
            } else {
                Text(planet.nameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: size.width / 2.0))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: size.width, height: size.height, alignment: .center)
                    .background(LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: planet.id),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .cornerRadius(cornerRadius)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            .overlay {
                                if isHovering {
                                    editLabel()
                                }
                            }
            }
        }
        .onTapGesture {
            if let url = chooseImageFileToUpload() {
                do {
                    switch artworkType {
                        case .avatar:
                            try planet.updateAvatar(path: url)
                        case .podcastCoverArt:
                            try planet.updatePodcastCoverArt(path: url)
                    }
                } catch {
                    debugPrint("failed to choose image file: \(error)")
                }
            } else {
                debugPrint("failed to choose image file.")
            }
        }
        .contextMenu {
            VStack {
                Button {
                    if let url = chooseImageFileToUpload() {
                        do {
                            switch artworkType {
                                case .avatar:
                                    try planet.updateAvatar(path: url)
                                case .podcastCoverArt:
                                    try planet.updatePodcastCoverArt(path: url)
                            }
                        } catch {
                            debugPrint("failed to choose image file: \(error)")
                        }
                    } else {
                        debugPrint("failed to choose image file.")
                    }
                } label: {
                    Text("Upload Artwork")
                }

                Button {
                    do {
                        switch artworkType {
                            case .avatar:
                                try planet.removeAvatar()
                            case .podcastCoverArt:
                                try planet.removePodcastCoverArt()
                        }
                    } catch {
                        debugPrint("failed to remove avatar: \(error)")
                    }
                } label: {
                    Text("Delete Artwork")
                }
            }
        }
        .onDrop(of: [.fileURL], delegate: dragAndDrop)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }

    private func chooseImageFileToUpload() -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Choose Artwork"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.canChooseDirectories = false
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        return url
    }

    private func getArtworkImage() -> NSImage? {
        switch artworkType {
            case .avatar:
                return planet.avatar
            case .podcastCoverArt:
                return planet.podcastCoverArt
        }
    }

    private func editLabel() -> some View {
        VStack (spacing: 0) {
            Spacer()
            HStack {
                Spacer()
                Text("Edit")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                Spacer()
            }
            Spacer()
        }
        .background(Color.black.opacity(0.5))
        .cornerRadius(cornerRadius)
    }
}


class ArtworkDragAndDrop: ObservableObject, DropDelegate {
    @ObservedObject var planet: MyPlanetModel
    var artworkType: PlanetArtworkType

    init(planet: MyPlanetModel, artworkType: PlanetArtworkType) {
        self.planet = planet
        self.artworkType = artworkType
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.itemProviders(for: [.fileURL]).first != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        let supportedExtensions = ["png", "jpeg", "tiff", "jpg"]
        Task {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
               let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil),
               supportedExtensions.contains(url.pathExtension) {
                switch self.artworkType {
                    case .avatar:
                        try self.planet.updateAvatar(path: url)
                    case .podcastCoverArt:
                        try self.planet.updatePodcastCoverArt(path: url)
                }
            }
        }
        return true
    }
}
