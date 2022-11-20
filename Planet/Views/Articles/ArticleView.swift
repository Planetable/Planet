import SwiftUI

struct ArticleView: View {
    static let noSelectionURL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
    @EnvironmentObject var planetStore: PlanetStore

    @State private var url = Self.noSelectionURL
    @State private var isShowingAnalyticsPopover: Bool = false
    @State private var selectedAttachment: String? = nil

    @State private var isSharing = false

    @State private var sharingItem: URL?
    @State private var currentItemHost: String? = nil
    @State private var currentItemLink: String? = nil

    var body: some View {
        VStack {
            ArticleAudioPlayer()
            ArticleWebView(url: $url)
        }
        .frame(minWidth: 400)
        .background(
            Color(NSColor.textBackgroundColor)
        )
        .onChange(of: planetStore.selectedArticle) { newArticle in
            if let myArticle = newArticle as? MyArticleModel {
                url = myArticle.publicIndexPath
                sharingItem = myArticle.browserURL?.absoluteURL
                currentItemLink = myArticle.link
            }
            else if let followingArticle = newArticle as? FollowingArticleModel {
                if let webviewURL = followingArticle.webviewURL {
                    url = webviewURL
                }
                else {
                    debugPrint("Failed to switch selected article - branch A")
                    url = Self.noSelectionURL
                }
                sharingItem = followingArticle.browserURL?.absoluteURL
                currentItemLink = followingArticle.link
                if followingArticle.planet.planetType == .ens {
                    currentItemHost = followingArticle.planet.link
                }
                if followingArticle.planet.planetType == .dotbit {
                    currentItemHost = followingArticle.planet.link
                }
                planetStore.walletTransactionMemo = "planet:\(currentItemHost)\(currentItemLink)"
            }
            else {
                debugPrint("Failed to switch selected article - branch B")
                url = Self.noSelectionURL
                currentItemLink = nil
                planetStore.walletTransactionMemo = ""
            }
            if let linkString = currentItemLink, !linkString.hasPrefix("/"), let linkURL = URL(string: linkString) {
                var link = linkURL.path
                if let query = linkURL.query {
                    link.append("?" + query)
                }
                if let fragment = linkURL.fragment {
                    link.append("#" + fragment)
                }
                currentItemLink = link
            }
            debugPrint("Current item link is \(currentItemLink ?? "nil")")
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
        .onChange(of: planetStore.selectedView) { _ in
            url = Self.noSelectionURL
            currentItemLink = nil
            planetStore.walletTransactionMemo = ""
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                switch planetStore.selectedView {
                case .myPlanet(let planet):
                    Button {
                        do {
                            try WriterStore.shared.newArticle(for: planet)
                        }
                        catch {
                            PlanetStore.shared.alert(title: "Failed to launch writer")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    if let plausibleEnabled = planet.plausibleEnabled, plausibleEnabled {
                        Button {
                            isShowingAnalyticsPopover = true
                            Task(priority: .userInitiated) {
                                await planet.updateTrafficAnalytics()
                            }
                        } label: {
                            Image(systemName: "chart.xyaxis.line")
                        }
                        .popover(isPresented: $isShowingAnalyticsPopover, arrowEdge: .bottom) {
                            PlausiblePopoverView(planet: planet)
                        }
                    }

                    Button {
                        planetStore.isShowingPlanetInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                case .followingPlanet(let planet):
                    Button {
                        planetStore.isShowingPlanetInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    if let receiver = canTip(planet: planet) {
                        Button {
                            planetStore.isShowingWalletTipAmount = true
                            /* Previous logic for sending test transaction
                            let ens = planet.link
                            let message: String
                            message = "Sending 0.01 Ξ to **\(ens)** on test network, please confirm from your phone"
                            Task { @MainActor in
                                PlanetStore.shared.walletTransactionProgressMessage = message
                                PlanetStore.shared.isShowingWalletTransactionProgress = true
                            }
                            let memo: String
                            if let link = currentItemLink {
                                memo = "planet:\(planet.link)\(link)"
                            } else {
                                memo = "planet:\(planet.link)"
                            }
                            WalletManager.shared.walletConnect.sendTestTransaction(receiver: receiver, amount: 5, memo: memo, ens: ens)
                            // WalletManager.shared.walletConnect.sendTransaction(receiver: receiver, amount: 5, memo: memo, ens: ens)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                PlanetStore.shared.isShowingWalletTransactionProgress = false
                            }
                            */
                        } label: {
                            Image(systemName: "gift")
                        }.help("Tip")
                    }
                default:
                    Text("")
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                if let article = planetStore.selectedArticle,
                    article.hasAudio
                {
                    if let myArticle = article as? MyArticleModel,
                        let name = myArticle.audioFilename,
                        let url = myArticle.getAttachmentURL(name: name)
                    {
                        Button {
                            ArticleAudioPlayerViewModel.shared.url = url
                            ArticleAudioPlayerViewModel.shared.title = article.title
                        } label: {
                            Label("Play Audio", systemImage: "headphones")
                        }
                    }
                    if let followingArticle = article as? FollowingArticleModel,
                        let name = followingArticle.audioFilename,
                        let url = followingArticle.getAttachmentURL(name: name)
                    {
                        Button {
                            ArticleAudioPlayerViewModel.shared.url = url
                            ArticleAudioPlayerViewModel.shared.title = article.title
                        } label: {
                            Label("Play Audio", systemImage: "headphones")
                        }
                    }
                }

                // Menu for accessing the attachments if any
                if let article = planetStore.selectedArticle, let attachments = article.attachments,
                    attachments.count > 0
                {
                    Menu {
                        ForEach(attachments, id: \.self) { attachment in
                            Button {
                                let downloadsPath = FileManager.default.urls(
                                    for: .downloadsDirectory,
                                    in: .userDomainMask
                                ).first
                                if let myArticle = article as? MyArticleModel {
                                    if let attachmentURL = myArticle.getAttachmentURL(
                                        name: attachment
                                    ),
                                        let destinationURL = downloadsPath?.appendingPathComponent(
                                            attachment
                                        )
                                    {
                                        if !FileManager.default.fileExists(
                                            atPath: destinationURL.path
                                        ) {
                                            try? FileManager.default.copyItem(
                                                at: attachmentURL,
                                                to: destinationURL
                                            )
                                        }
                                        NSWorkspace.shared.activateFileViewerSelecting([
                                            destinationURL
                                        ])
                                    }
                                }
                                if let followingArticle = article as? FollowingArticleModel {
                                    if let attachmentURL = followingArticle.getAttachmentURL(
                                        name: attachment
                                    ) {
                                        // MARK: TODO: should hide download button if any
                                        if PlanetDownloadItem.downloadableFileExtensions().contains(
                                            attachmentURL.pathExtension
                                        ) {
                                            NotificationCenter.default.post(
                                                name: .downloadArticleAttachment,
                                                object: attachmentURL
                                            )
                                        }
                                    }
                                }
                            } label: {
                                Text(attachment)
                            }
                        }
                    } label: {
                        Image(systemName: "paperclip")
                        Text("\(attachments.count)")
                    }
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                if let article = planetStore.selectedArticle {
                    Spacer()
                    Button {
                        isSharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .background(
                        SharingServicePicker(isPresented: $isSharing, sharingItems: [sharingItem ?? URL(string: "https://planetable.eth.limo")!])
                    )
                }
            }
        }
    }

    private func canTip(planet: FollowingPlanetModel) -> String? {
        debugPrint("Tipping: Following Planet \(planet.walletAddress)")
        guard let walletAddress = planet.walletAddress else { return nil }
        let myWalletAddress = planetStore.walletAddress
        debugPrint("Tipping: My Wallet \(myWalletAddress) / Author Wallet \(walletAddress)")
        if myWalletAddress.count == 42, myWalletAddress.lowercased() != walletAddress.lowercased() {
            return walletAddress
        }
        return nil
    }
}
