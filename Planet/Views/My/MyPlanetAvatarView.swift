import SwiftUI
import UniformTypeIdentifiers


struct MyPlanetAvatarView: View {
    @ObservedObject var planet: MyPlanetModel
    @State var isChoosingAvatarImage = false
    @StateObject var dragAndDrop: AvatarDragAndDrop

    init(planet: MyPlanetModel) {
        self.planet = planet
        self._dragAndDrop = StateObject(wrappedValue: AvatarDragAndDrop(planet: planet))
    }

    var body: some View {
        VStack {
            if let image = planet.avatar {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80, alignment: .center)
                    .cornerRadius(40)
                    .overlay(RoundedRectangle(cornerRadius: 40)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            } else {
                Text(planet.nameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: 40))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: 80, height: 80, alignment: .center)
                    .background(LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: planet.id),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .cornerRadius(40)
                    .overlay(RoundedRectangle(cornerRadius: 40)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
        }
        .onTapGesture {
            isChoosingAvatarImage = true
        }
        .fileImporter(
            isPresented: $isChoosingAvatarImage,
            allowedContentTypes: [.png, .jpeg, .tiff],
            allowsMultipleSelection: false
        ) { result in
            if let urls = try? result.get(),
               let url = urls.first {
                do {
                    try planet.updateAvatar(path: url)
                } catch {
                    // TODO: alert
                }
            }
        }
        .contextMenu {
            VStack {
                Button {
                    isChoosingAvatarImage = true
                } label: {
                    Text("Upload Avatar")
                }

                Button {
                    do {
                        try planet.removeAvatar()
                    } catch {
                        // TODO: alert
                    }
                } label: {
                    Text("Delete Avatar")
                }
            }
        }
        .onDrop(of: [.fileURL], delegate: dragAndDrop)
    }
}

class AvatarDragAndDrop: ObservableObject, DropDelegate {
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
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
               let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil),
               supportedExtensions.contains(url.pathExtension) {
                try self.planet.updateAvatar(path: url)
            }
        }
        return true
    }
}
