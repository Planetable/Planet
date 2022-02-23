//
//  PlanetAboutView.swift
//  Planet
//
//  Created by Kai on 2/21/22.
//

import SwiftUI


private struct SharingsPicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    var sharingItems: [Any] = []

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            let picker = NSSharingServicePicker(items: sharingItems)
            picker.delegate = context.coordinator
            DispatchQueue.main.async {
                picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    class Coordinator: NSObject, NSSharingServicePickerDelegate {
        let owner: SharingsPicker

        init(owner: SharingsPicker) {
            self.owner = owner
        }

        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            sharingServicePicker.delegate = nil
            self.owner.isPresented = false
        }
    }
}


struct PlanetAboutView: View {
    var planet: Planet
    
    @State private var isSharing = false
    @State private var planetIPNS = "planet://"

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80, alignment: .center)
                    .cornerRadius(40)
                Spacer()
            }
            .padding(15)
            
            HStack {
                Spacer()
                Text(planet.name ?? "")
                    .font(.title)
                Spacer()
            }
            HStack {
                Spacer()
                Text(planet.about ?? "")
                    .font(.body)
                Spacer()
            }
            
            Spacer()
            
            HStack {
                if planet.isMyPlanet() {
                    if let ipns = planet.ipns, ipns != "" {
                        Button {
                            isSharing = true
                            planetIPNS = "planet://" + ipns
                        } label: {
                            Text("Share")
                        }
                    }

                    Button {
                        
                    } label: {
                        Text("Edit")
                    }
                    
                    Spacer()
                    
                    Button {
                        PlanetDataController.shared.removePlanet(planet: planet)
                    } label: {
                        Text("Delete")
                    }
                } else {
                    if let ipns = planet.ipns, ipns != "" {
                        Button {
                            isSharing = true
                            planetIPNS = "planet://" + ipns
                        } label: {
                            Text("Share")
                        }
                    }

                    Spacer()
                    
                    Button {
                        PlanetDataController.shared.removePlanet(planet: planet)
                    } label: {
                        Text("Unfollow")
                    }
                }
            }
        }
        .padding()
        .frame(width: 280, height: 250, alignment: .center)
        .background(
            SharingsPicker(isPresented: $isSharing, sharingItems: [planetIPNS])
        )
    }
}

struct PlanetAboutView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAboutView(planet: Planet())
    }
}
