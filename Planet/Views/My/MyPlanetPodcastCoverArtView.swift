//
//  MyPlanetPodcastCoverArtView.swift
//  Planet
//
//  Created by Xin Liu on 10/10/22.
//

import SwiftUI

struct MyPlanetPodcastCoverArtView: View {
    let CORNER_RADIUS: CGFloat = 16

    @ObservedObject var planet: MyPlanetModel
    @State var isChoosingCoverArtImage = false
    @StateObject var dragAndDrop: CoverArtDragAndDrop

    init(planet: MyPlanetModel) {
        self.planet = planet
        self._dragAndDrop = StateObject(wrappedValue: CoverArtDragAndDrop(planet: planet))
    }

    var body: some View {
        VStack {
            if let image = planet.podcastCoverArt {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128, alignment: .center)
                    .cornerRadius(CORNER_RADIUS)
                    .overlay(RoundedRectangle(cornerRadius: CORNER_RADIUS)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            } else {
                Text(planet.nameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: 40))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: 128, height: 128, alignment: .center)
                    .background(LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: planet.id),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .cornerRadius(CORNER_RADIUS)
                    .overlay(RoundedRectangle(cornerRadius: CORNER_RADIUS)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
        }
        .onTapGesture {
            isChoosingCoverArtImage = true
        }
        .fileImporter(
            isPresented: $isChoosingCoverArtImage,
            allowedContentTypes: [.png, .jpeg, .tiff],
            allowsMultipleSelection: false
        ) { result in
            if let urls = try? result.get(),
               let url = urls.first {
                do {
                    try planet.updatePodcastCoverArt(path: url)
                } catch {
                    // TODO: alert
                }
            }
        }
        .contextMenu {
            VStack {
                Button {
                    isChoosingCoverArtImage = true
                } label: {
                    Text("Upload Cover Art")
                }

                Button {
                    do {
                        try planet.removePodcastCoverArt()
                    } catch {
                        // TODO: alert
                    }
                } label: {
                    Text("Delete Cover Art")
                }
            }
        }
        .onDrop(of: [.fileURL], delegate: dragAndDrop)
    }
}

class CoverArtDragAndDrop: ObservableObject, DropDelegate {
    @ObservedObject var planet: MyPlanetModel

    init(planet: MyPlanetModel) {
        self.planet = planet
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.itemProviders(for: [.fileURL]).first != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        let supportedExtensions = ["png", "jpeg", "gif", "tiff", "jpg"]
        Task {
            // fix deprecated: import UniformTypeIdentifiers and use UTType.fileURL instead
            if let item = try? await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String),
               let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil),
               supportedExtensions.contains(url.pathExtension) {
                try self.planet.updatePodcastCoverArt(path: url)
            }
        }
        return true
    }
}
