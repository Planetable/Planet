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
    @EnvironmentObject private var planetStore: PlanetStore

    @Environment(\.dismiss) private var dismiss

    var planet: Planet
    
    @State private var isSharing = false
    @State private var planetIPNS = "planet://"

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    PlanetAvatarView(planet: planet, size: CGSize(width: 80, height: 80), inEditMode: planet.isMyPlanet())
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.bottom, 5)
                
                HStack {
                    Spacer()
                    Text(planet.name ?? "")
                        .font(.title)
                    Spacer()
                }
                Text(planet.about ?? "")
                    .font(.body)

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
                            dismiss()
                            Task.init {
                                await PlanetManager.shared.publishForPlanet(planet: planet)
                            }
                        } label: {
                            Text(planetStore.publishingPlanets.contains(planet.id!) ? "Publishing" : "Publish")
                        }
                        .disabled(planetStore.publishingPlanets.contains(planet.id!))
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                            planetStore.isEditingPlanet = true
                        } label: {
                            Text("Edit")
                        }
                        
                        Button {
                            dismiss()
                            Task.init {
                                PlanetDataController.shared.removePlanet(planet: planet)
                            }
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
                        
                        Button {
                            dismiss()
                            Task.init {
                                await PlanetManager.shared.updateForPlanet(planet: planet)
                            }
                        } label: {
                            Text(planetStore.updatingPlanets.contains(planet.id!) ? "Updating" : "Update")
                        }
                        .disabled(planetStore.updatingPlanets.contains(planet.id!))

                        Spacer()
                        
                        Button {
                            dismiss()
                            Task.init {
                                PlanetDataController.shared.removePlanet(planet: planet)
                            }
                        } label: {
                            Text("Unfollow")
                        }
                    }
                }
            }
            .background(
                SharingsPicker(isPresented: $isSharing, sharingItems: [planetIPNS])
            )
            
            VStack {
                HStack {
                    Text(planet.isMyPlanet() ? lastPublishedStatus() : lastUpdatedStatus())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .updateAvatar, object: nil)
                        }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16, alignment: .center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                }
                Spacer()
            }
        }
        .padding()
        .frame(width: 320, height: 260, alignment: .center)
    }
    
    private func lastUpdatedStatus() -> String {
        if let id = planet.id {
            if let updated = planetStore.lastUpdatedDates[id] {
                return "Updated " + updated.relativeDateDescription()
            } else if let updated = UserDefaults.standard.object(forKey: "PlanetLastUpdated" + "-" + id.uuidString) as? Date {
                return "Updated " + updated.relativeDateDescription()
            }
        }
        return "Never Updated"
    }
    
    private func lastPublishedStatus() -> String {
        if let id = planet.id {
            if let published = planetStore.lastPublishedDates[id] {
                return "Published " + published.relativeDateDescription()
            } else if let published = UserDefaults.standard.object(forKey: "PlanetLastPublished" + "-" + id.uuidString) as? Date {
                return "Published " + published.relativeDateDescription()
            }
        }
        return "Never Published"
    }
}

struct PlanetAboutView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAboutView(planet: Planet())
    }
}
