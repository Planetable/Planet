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

        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
            guard let image = NSImage(named: NSImage.networkName) else {
                return proposedServices
            }
            var share = proposedServices
            let copyService = NSSharingService(title: "Copy Planet IPNS", image: image, alternateImage: image, handler: {
                if let ipns = items.first as? String {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ipns, forType: .string)
                }
            })
            share.insert(copyService, at: 0)
            return share
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

    @ObservedObject private var statusViewModel: PlanetStatusViewModel = PlanetStatusViewModel.shared

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
                                planet.isPublishing = true
                                do {
                                    try await PlanetManager.shared.publish(planet)
                                } catch {}
                                planet.isPublishing = false
                            }
                        } label: {
                            Text(planet.isPublishing ? "Publishing" : "Publish")
                        }
                        .disabled(planet.isPublishing)

                        Spacer()

                        Button {
                            dismiss()
                            planetStore.isEditingPlanet = true
                        } label: {
                            Text("Edit")
                        }

                        Button {
                            Task.init {
                                await PlanetDataController.shared.remove(planet)
                                PlanetDataController.shared.save()
                                dismiss()
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
                            Task.init {
                                planet.isUpdating = true
                                try? await PlanetManager.shared.update(planet)
                                planet.isUpdating = false
                                dismiss()
                            }
                        } label: {
                            Text(planet.isUpdating ? "Updating" : "Update")
                        }
                        .disabled(planet.isUpdating)

                        Spacer()

                        Button {
                            Task.init {
                                await PlanetDataController.shared.remove(planet)
                                PlanetDataController.shared.save()
                                dismiss()
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
        if let updated = planet.lastUpdated {
            return "Updated " + updated.relativeDateDescription()
        }
        return "Never Updated"
    }

    private func lastPublishedStatus() -> String {
        if let published = planet.lastPublished {
            return "Published " + published.relativeDateDescription()
        }
        return "Never Published"
    }
}
