//
//  PlanetKeyManagerView.swift
//  Planet
//
//  Created by Kai on 3/9/23.
//

import SwiftUI


struct PlanetKeyManagerView: View {
    @StateObject private var keyManagerViewModel: PlanetKeyManagerViewModel
    
    init() {
        _keyManagerViewModel = StateObject(wrappedValue: PlanetKeyManagerViewModel.shared)
    }

    var body: some View {
        VStack {
            switch keyManagerViewModel.refreshing {
            case true:
                loadingView()
            case false:
                contentView()
            }
        }
        .frame(minWidth: 480, idealWidth: 480, maxWidth: .infinity, minHeight: 320, idealHeight: 320, maxHeight: .infinity)
        .padding(0)
        .task {
            await self.keyManagerViewModel.reloadPlanetKeys()
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyManagerReloadUI)) { _ in
            Task { @MainActor in
                await self.keyManagerViewModel.reloadPlanetKeys()
            }
        }
    }
    
    @ViewBuilder
    private func loadingView() -> some View {
        Text("Reloading...")
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func contentView() -> some View {
        Table(keyManagerViewModel.keys, selection: $keyManagerViewModel.selectedKeyItemID) {
            TableColumn("Planet", value: \.planetName)
            TableColumn("Key Name", value: \.keyName)
            TableColumn("Key ID", value: \.keyID)
            TableColumn("Keystore Status") { item in
                if keyManagerViewModel.keysInKeystore.contains(item.keyName) {
                    Label("In Keystore", systemImage: "checkmark.circle")
                } else {
                    Label("Not in Keystore", systemImage: "poweroff")
                }
            }
            TableColumn("Keychain Status") { item in
                if KeychainHelper.shared.check(forKey: item.keyName) {
                    Label("In Keychain", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                } else {
                    Label("Not in Keychain", systemImage: "poweroff")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct PlanetKeyManagerView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetKeyManagerView()
    }
}
