import SwiftUI


struct IconGalleryView: View {
    @EnvironmentObject private var iconManager: IconManager

    @State private var selectedGroupName: String?
    @State private var selectedDockIcon: DockIcon?

    static let itemSize: NSSize = NSSize(width: 120, height: 120)
    static let previewItemSize: NSSize = NSSize(width: 180, height: 180)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List(selection: $selectedGroupName) {
                    ForEach(iconManager.iconGroupNames(), id: \.self) { name in
                        Text(name)
                    }
                }
                .listStyle(.sidebar)
                
                Spacer(minLength: 20)
                
                if let selectedDockIcon {
                    iconManager.iconPreview(icon: selectedDockIcon, size: Self.previewItemSize)
                } else if let currentDockIcon = iconManager.activeDockIcon {
                    iconManager.iconPreview(icon: currentDockIcon, size: Self.previewItemSize)
                }
            }
            .frame(width: 180)
            
            VStack(spacing: 0) {
                if let selectedGroupName {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.itemSize.width, maximum: Self.itemSize.height), spacing: 0, alignment: .center)], alignment: .center) {
                            ForEach(iconManager.dockIcons.filter({ $0.groupName == selectedGroupName }), id: \.self) { icon in
                                iconManager.iconPreview(icon: icon, size: Self.itemSize, previewable: false)
                                    .onTapGesture {
                                        selectedDockIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    
                    Divider()
                    
                    HStack {
                        if iconManager.activeDockIcon != nil && selectedDockIcon != nil {
                            Button {
                                iconManager.resetIcon()
                                selectedDockIcon = nil
                            } label: {
                                Text("Reset App Icon")
                            }
                        } else if iconManager.activeDockIcon != nil {
                            Button {
                                iconManager.resetIcon()
                                selectedDockIcon = nil
                            } label: {
                                Text("Reset App Icon")
                            }
                        } else {
                            Text("Select to Preview and Set App Icon")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        /* // MARK: TODO: pinnable
                        let unlocked = selectedDockIcon?.unlocked ?? false
                        if !unlocked && selectedDockIcon != nil {
                            HStack {
                                Text("Icon Locked")
                                    .foregroundColor(.secondary)
                                HelpLinkButton(helpLink: URL(string: "https://pinnable.xyz/pricing")!)
                            }
                        } else {
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
                         */
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
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                } else {
                    Text("No Icon Selected")
                }
            }
            .frame(minWidth: 420, idealWidth: 420)
        }
        .frame(minWidth: 600, idealWidth: 600, maxWidth: .infinity, minHeight: 400)
        .task {
            if let icon = iconManager.activeDockIcon {
                selectedGroupName = icon.groupName
            } else {
                selectedGroupName = iconManager.iconGroupNames().first
            }
            let lastPackageName = UserDefaults.standard.string(forKey: "PlanetDockIconLastPackageName") ?? ""
            DistributedNotificationCenter.default().post(name: Notification.Name("PlanetDockIconSyncPackageName"), object: lastPackageName)
        }
    }
}

struct IconGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        IconGalleryView()
    }
}
