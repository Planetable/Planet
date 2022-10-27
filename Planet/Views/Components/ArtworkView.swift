//
//  ArtworkView.swift
//  Planet
//
//  Created by Kai on 10/26/22.
//

import SwiftUI
import UniformTypeIdentifiers


struct ArtworkView: View {
    private var dragAndDrop: ArtworkDragAndDrop

    var image: NSImage?
    var planetNameInitials: String
    var planetID: UUID
    var cornerRadius: CGFloat
    var size: CGSize
    let uploadAction: (URL) -> Void
    let deleteAction: () -> Void

    @State private var isHovering: Bool = false

    init(image: NSImage?, planetNameInitials: String, planetID: UUID, cornerRadius: CGFloat = 0, size: CGSize = .zero, uploadAction: @escaping ((URL) -> Void), deleteAction: @escaping (() -> Void)) {
        self.image = image
        self.planetNameInitials = planetNameInitials
        self.planetID = planetID
        self.cornerRadius = cornerRadius
        self.size = size
        self.uploadAction = uploadAction
        self.deleteAction = deleteAction
        self.dragAndDrop = ArtworkDragAndDrop(uploadAction: uploadAction)
    }

    var body: some View {
        VStack {
            if let image = image {
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
                Text(planetNameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: size.width / 2.0))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: size.width, height: size.height, alignment: .center)
                    .background(LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: planetID),
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
                uploadAction(url)
            } else {
                debugPrint("failed to choose image file.")
            }
        }
        .contextMenu {
            VStack {
                Button {
                    if let url = chooseImageFileToUpload() {
                        uploadAction(url)
                    } else {
                        debugPrint("failed to choose image file.")
                    }
                } label: {
                    Text("Upload Artwork")
                }

                Button {
                    deleteAction()
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


private class ArtworkDragAndDrop: DropDelegate {
    let uploadAction: (URL) -> Void

    init(uploadAction: @escaping ((URL) -> Void)) {
        self.uploadAction = uploadAction
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
                self.uploadAction(url)
            }
        }
        return true
    }
}
