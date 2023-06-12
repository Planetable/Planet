//
//  PlanetMainView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI
import UniformTypeIdentifiers


struct PlanetMainView: View {
    @EnvironmentObject var planetStore: PlanetStore

    @State private var isInfoAlert: Bool = false
    @State private var isFollowingAlert: Bool = false

    let planetDataIdentifier = {
        if let name = Bundle.main.object(forInfoDictionaryKey: "ORGANIZATION_IDENTIFIER_PREFIX") as? String {
            return name + ".planet.data"
        } else {
            return "xyz.planetable.planet.data"
        }
    }()

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
        .fileImporter(
            isPresented: $planetStore.isImportingPlanet,
            allowedContentTypes: [UTType(planetDataIdentifier)!]
        ) { result in
            if let url = try? result.get() {
                do {
                    let planet = try MyPlanetModel.importBackup(from: url)
                    planetStore.myPlanets.insert(planet, at: 0)
                    planetStore.selectedView = .myPlanet(planet)
                } catch {
                    planetStore.alert(title: "Failed to import planet")
                }
            }
        }
        .sheet(isPresented: $planetStore.isShowingPlanetInfo) {
            if case .myPlanet(let planet) = planetStore.selectedView {
                MyPlanetInfoView(planet: planet)
            } else
            if case .followingPlanet(let planet) = planetStore.selectedView {
                FollowingPlanetInfoView(planet: planet)
            }
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
                .frame(width: .sheetWidth, height: .sheetHeight + 28)
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
