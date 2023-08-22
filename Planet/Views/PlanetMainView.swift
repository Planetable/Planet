//
//  PlanetMainView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetMainView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @EnvironmentObject private var iconManager: IconManager

    @AppStorage("PlanetAvatarPicker.selectedAvatarCategory") private var selectedAvatarCategory: AvatarCategory?

    @State private var isInfoAlert: Bool = false
    @State private var isFollowingAlert: Bool = false

    var body: some View {
        NavigationView {
            PlanetSidebarView()

            ArticleListView()

            ArticleView()
                .edgesIgnoringSafeArea(.vertical)
        }
        .alert(isPresented: $planetStore.isShowingAlert) {
            Alert(
                title: Text(planetStore.alertTitle),
                message: Text(planetStore.alertMessage),
                dismissButton: Alert.Button.cancel(Text("OK")) {
                    planetStore.alertTitle = ""
                    planetStore.alertMessage = ""
                }
            )
        }
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetInfoView(planet: planet)
            } else
            if case .followingPlanet(let planet) = planetStore.selectedView {
                FollowingPlanetInfoView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isShowingPlanetAvatarPicker) {
            AvatarPickerView(selection: $selectedAvatarCategory)
        }
        .sheet(isPresented: $planetStore.isEditingPlanet) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetEditView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isShowingMyArticleSettings) {
            if let article: MyArticleModel = planetStore.selectedArticle as? MyArticleModel {
                MyArticleSettingsView(article: article)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanetCustomCode) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetCustomCodeView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isShowingPlanetIPNS) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetIPNSView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isEditingPlanetPodcastSettings) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetPodcastSettingsView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isConfiguringPlanetTemplate) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetTemplateSettingsView(planet: planet)
            }
        }
        .sheet(isPresented: $planetStore.isMigrating) {
            MigrationProgressView()
        }
        .sheet(isPresented: $planetStore.isRebuilding) {
            RebuildProgressView()
        }
        .sheet(isPresented: $planetStore.isShowingWalletConnectV1QRCode) {
            WalletConnectV1QRCodeView(payload: planetStore.walletConnectV1ConnectionURL)
        }
        .sheet(isPresented: $planetStore.isShowingWalletConnectV2QRCode) {
            WalletConnectV2QRCodeView(payload: planetStore.walletConnectV2ConnectionURL)
        }
        .sheet(isPresented: $planetStore.isShowingWalletTipAmount) {
            if case .followingPlanet(let planet) = planetStore.selectedView, let receiver = planet.walletAddress, planet.link.hasSuffix(".eth") {
                TipSelectView(receiver: receiver, ens: planet.link, memo: planetStore.walletTransactionMemo)
            }
        }
        .sheet(isPresented: $planetStore.isShowingWalletTransactionProgress) {
            WalletTransactionProgressView(message: planetStore.walletTransactionProgressMessage)
        }
        .sheet(isPresented: $planetStore.isShowingWalletAccount) {
            WalletAccountView(walletAddress: planetStore.walletAddress)
        }
        .sheet(isPresented: $planetStore.isQuickSharing) {
            PlanetQuickShareView()
                .frame(width: .sheetWidth)
                .frame(minHeight: .sheetHeight)
        }
        .sheet(isPresented: $planetStore.isShowingIconGallery) {
            IconGalleryView()
                .environmentObject(iconManager)
        }
        .confirmationDialog(
            Text("Are you sure you want to disconnect?"),
            isPresented: $planetStore.isShowingWalletDisconnectConfirmation
        ) {
            Button() {
                try? WalletManager.shared.walletConnect.client.disconnect(from: WalletManager.shared.walletConnect.session)
            } label: {
                Text("Disconnect")
            }
        }
        .sheet(isPresented: $planetStore.isShowingOnboarding) {
            OnboardingView()
        }
    }
}

struct PlanetMainView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMainView()
    }
}
