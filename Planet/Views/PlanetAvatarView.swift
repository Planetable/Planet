//
//  PlanetAvatarView.swift
//  Planet
//
//  Created by Kai on 2/24/22.
//

import SwiftUI


struct PlanetAvatarView: View {
    var planet: Planet
    var size: CGSize
    var inEditMode: Bool = false
    
    @State private var updatedAvatarImage: NSImage!
    @State private var isChoosingAvatarImage: Bool = false

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
                PlanetManager.shared.updateAvatar(forPlanet: planet, image: targetImage, isEditing: inEditMode)
                DispatchQueue.main.async {
                    self.updatedAvatarImage = targetImage
                }
            }
        }
        .onAppear {
            if let img = PlanetManager.shared.avatar(forPlanet: planet) {
                DispatchQueue.main.async {
                    self.updatedAvatarImage = img
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateAvatar, object: nil)) { _ in
            if let img = PlanetManager.shared.avatar(forPlanet: planet) {
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
                        PlanetManager.shared.removeAvatar(forPlanet: planet)
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
    }
}

struct PlanetAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAvatarView(planet: Planet(), size: CGSize(width: 64, height: 64))
    }
}
