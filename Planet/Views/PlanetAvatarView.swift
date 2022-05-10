//
//  PlanetAvatarView.swift
//  Planet
//
//  Created by Kai on 2/24/22.
//

import SwiftUI


struct PlanetAvatarView: View {
    var size: CGSize
    var inEditMode: Bool = false
    @ObservedObject var planet: Planet

    @State private var updatedAvatarImage: NSImage!
    @State private var isChoosingAvatarImage: Bool = false
    @ObservedObject private var avatarViewModel: PlanetAvatarViewModel

    init(planet: Planet, size: CGSize, inEditMode: Bool = false) {
        self.planet = planet
        self.size = size
        self.inEditMode = inEditMode
        _avatarViewModel = ObservedObject(wrappedValue: PlanetAvatarViewModel.shared)
        if let img = planet.avatar() {
            _updatedAvatarImage = State(wrappedValue: img)
        }
    }

    var body: some View {
        VStack {
            if updatedAvatarImage == nil {
                Text(planet.generateAvatarName())
                    .font(Font.custom("Arial Rounded MT Bold", size: size.width / 2.0))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: size.width, height: size.height, alignment: .center)
                    .background(LinearGradient(gradient: planet.gradient(), startPoint: .top, endPoint: .bottom))
                    .cornerRadius(size.width / 2)
            } else {
                Image(nsImage: updatedAvatarImage!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height, alignment: .center)
                    .cornerRadius(size.width / 2)
            }
        }
        .onTapGesture {
            guard inEditMode else { return }
            isChoosingAvatarImage = true
        }
        .fileImporter(isPresented: $isChoosingAvatarImage, allowedContentTypes: [.png, .jpeg, .tiff], allowsMultipleSelection: false) { result in
            if let urls = try? result.get(), let url = urls.first, let img = NSImage(contentsOf: url) {
                let targetImage = PlanetManager.shared.resizedAvatarImage(image: img)
                planet.updateAvatar(image: targetImage, isEditing: inEditMode)
                DispatchQueue.main.async {
                    self.updatedAvatarImage = targetImage
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateAvatar, object: nil)) { _ in
            if let img = planet.avatar() {
                DispatchQueue.main.async {
                    self.updatedAvatarImage = img
                }
            } else {
                DispatchQueue.main.async {
                    self.updatedAvatarImage = nil
                }
            }
        }
        .contextMenu {
            if inEditMode {
                VStack {
                    Button {
                        isChoosingAvatarImage = true
                    } label: {
                        Text("Upload Avatar")
                    }

                    Button {
                        planet.removeAvatar()
                        NotificationCenter.default.post(name: .updateAvatar, object: nil)
                        DispatchQueue.main.async {
                            self.updatedAvatarImage = nil
                        }
                    } label: {
                        Text("Delete Avatar")
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], delegate: avatarViewModel)
    }
}

struct PlanetAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAvatarView(planet: Planet(), size: CGSize(width: 64, height: 64))
    }
}
