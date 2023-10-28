import SwiftUI


struct IconGalleryView: View {
    @EnvironmentObject private var iconManager: IconManager

    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroupName: String?
    @State private var selectedDockIcon: DockIcon?

    static let itemSize: NSSize = NSSize(width: 135, height: 135)
    static let previewItemSize: NSSize = NSSize(width: 180, height: 180)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List(selection: $selectedGroupName) {
                    ForEach(availableGroupsAndIcons().groups, id: \.self) { name in
                        Text(name)
                    }
                }
                .listStyle(.sidebar)

                Spacer(minLength: 20)

                if let selectedDockIcon, selectedDockIcon.verifyIconStatus() {
                    iconManager.iconPreview(icon: selectedDockIcon, size: Self.previewItemSize)
                } else if let currentDockIcon = iconManager.activeDockIcon, currentDockIcon.verifyIconStatus() {
                    iconManager.iconPreview(icon: currentDockIcon, size: Self.previewItemSize)
                }
            }
            .frame(width: 180)

            VStack(spacing: 0) {
                if selectedGroupName != nil {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.itemSize.width, maximum: Self.itemSize.height), spacing: 0, alignment: .center)], alignment: .center) {
                            ForEach(availableGroupsAndIcons().icons, id: \.self) { icon in
                                iconManager.iconPreview(icon: icon, size: Self.itemSize, previewable: false)
                                    .onTapGesture {
                                        selectedDockIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 20)
                    }

                    Divider()

                    HStack(spacing: 12) {
                        if (iconManager.activeDockIcon != nil && selectedDockIcon != nil) || iconManager.activeDockIcon != nil {
                            Button {
                                iconManager.resetIcon()
                                selectedDockIcon = nil
                            } label: {
                                Text("Reset App Icon")
                            }
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .frame(minWidth: PlanetUI.BUTTON_MIN_WIDTH_SHORT)
                        }

                        Button {
                            if let selectedDockIcon {
                                iconManager.setIcon(icon: selectedDockIcon)
                            }
                        } label: {
                            Text("Set App Icon")
                        }
                        .disabled(selectedDockIcon == nil)
                        .disabled(iconManager.activeDockIcon != nil && iconManager.activeDockIcon == selectedDockIcon)
                    }
                    .padding(16)
                } else {
                    Text("No Icon Selected")
                }
            }
            .frame(minWidth: 460, idealWidth: 460)
        }
        .frame(minWidth: 640, idealWidth: 640, maxWidth: .infinity, minHeight: 400)
        .task {
            if let icon = iconManager.activeDockIcon {
                selectedGroupName = icon.groupName
            } else {
                selectedGroupName = availableGroupsAndIcons().groups.first
            }
            let lastPackageName = UserDefaults.standard.string(forKey: "PlanetDockIconLastPackageName") ?? ""
            DistributedNotificationCenter.default().post(name: Notification.Name("xyz.planetable.Planet.PlanetDockIconSyncPackageName"), object: lastPackageName)
        }
    }

    private func availableGroupsAndIcons() -> (groups: [String], icons: [DockIcon]) {
        let availableIcons: [DockIcon] = iconManager.dockIcons.filter({ $0.verifyIconStatus() })
        let availableGroups: [String] = availableIcons.map() { icon in
            return icon.groupName
        }
        let groups: [String] = Array(Set(availableGroups)).sorted().reversed()
        let icons: [DockIcon] = availableIcons.filter({ $0.groupName == selectedGroupName })
        return (groups, icons)
    }
}

struct IconGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        IconGalleryView()
    }
}
