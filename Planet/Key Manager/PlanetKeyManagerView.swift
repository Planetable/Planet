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
        .frame(minWidth: 320, idealWidth: 320, maxWidth: .infinity, minHeight: 480, idealHeight: 480, maxHeight: .infinity)
        .padding(0)
        .task {
            await keyManagerViewModel.reloadPlanetKeys()
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
            TableColumn("Keychain Status") { item in
                if KeychainHelper.shared.check(forKey: item.keyName) {
                    Label("In Keychain", systemImage: "checkmark.circle")
                } else {
                    Label("Not in Keychain", systemImage: "poweroff")
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
