import SwiftUI

struct ArticleExternalLinkView: View {
    @ObservedObject var article: ArticleModel

    var body: some View {
        if let myArticle = article as? MyArticleModel, let link = myArticle.externalLink, link.count > 0 {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Button {
                        if let url = URL(string: link) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text(link)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }.buttonStyle(.link)
                    Spacer()
                }.padding(8)
            }
        }
    }
}

struct ArticleToolbarStarView: View {
    @ObservedObject var article: ArticleModel

    var body: some View {
        article.starView()
    }
}

struct ArticleSetStarView: View {
    @ObservedObject var article: ArticleModel

    var body: some View {
        Button {
            article.starred = Date()
            article.starType = .star
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "star.fill")
                Text("Star")
            }
        }
        if article.starred != nil {
            Divider()
            Button {
                article.starred = nil
                try? article.saveArticle()
            } label: {
                HStack {
                    Spacer()
                    Text("Remove Star")
                }
            }
        }
        Divider()
        todoStars()
        Divider()
        Button {
            article.starred = Date()
            article.starType = .sparkles
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Sparkles")
            }
        }
        Button {
            article.starred = Date()
            article.starType = .heart
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "heart.fill")
                Text("Heart")
            }
        }
        Button {
            article.starred = Date()
            article.starType = .question
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                Text("Question")
            }
        }
        Button {
            article.starred = Date()
            article.starType = .paperplane
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "paperplane.circle.fill")
                Text("Paperplane")
            }
        }
    }

    @ViewBuilder
    func todoStars() -> some View {
        Button {
            article.starred = Date()
            article.starType = .plan
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "circle.dotted")
                Text("Plan")
            }
        }
        Button {
            article.starred = Date()
            article.starType = .todo
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "circle")
                Text("To Do")
            }
        }
        Button {
            article.starred = Date()
            article.starType = .done
            try? article.saveArticle()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Done")
            }
        }
    }
}

struct ArticleView: View {
    static let noSelectionURL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
    @EnvironmentObject var planetStore: PlanetStore

    @State private var url: URL = Self.noSelectionURL
    @State private var isShowingAnalyticsPopover: Bool = false
    @State private var selectedAttachment: String? = nil

    @State private var isSharing: Bool = false

    @State private var sharingItem: URL?
    @State private var currentItemHost: String? = nil
    @State private var currentItemLink: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ArticleWebView(url: $url)
            ArticleAudioPlayer()
            if let article = planetStore.selectedArticle {
                ArticleExternalLinkView(article: article)
            }
        }
        .frame(minWidth: 400)
        .background(
            Color(NSColor.textBackgroundColor)
        )
        .onChange(of: planetStore.selectedArticle) { newArticle in
            if let myArticle = newArticle as? MyArticleModel {
                if myArticle.planet.templateName == "Croptop" {
                    if FileManager.default.fileExists(atPath: myArticle.publicSimplePath.path) {
                        let now = Date()
                        let simpleHTMLAge =
                            now.timeIntervalSince1970
                            - ((try? FileManager.default.attributesOfItem(
                                atPath: myArticle.publicSimplePath.path
                            )[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
                        if simpleHTMLAge < 7 {
                            url = myArticle.publicSimplePath
                        }
                        else {
                            url = myArticle.localPreviewURL ?? myArticle.publicIndexPath
                        }
                    }
                    else {
                        url = myArticle.localPreviewURL ?? myArticle.publicIndexPath
                    }
                }
                else {
                    // in future we can use the local gateway for all planets
                    url = myArticle.publicIndexPath
                }
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
            }
            else {
                debugPrint("Failed to switch selected article - branch B")
                url = Self.noSelectionURL
                currentItemLink = nil
                planetStore.walletTransactionMemo = ""
            }
            if let linkString = currentItemLink, !linkString.hasPrefix("/"),
                let linkURL = URL(string: linkString)
            {
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
            if let host = currentItemHost {
                planetStore.walletTransactionMemo = "planet:\(host)"
                if let link = currentItemLink {
                    planetStore.walletTransactionMemo = "planet:\(host)\(link)"
                }
            }
            debugPrint(
                "Current prepared transaction memo is \(planetStore.walletTransactionMemo)"
            )
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
        .onChange(of: planetStore.selectedView) { _ in
            url = Self.noSelectionURL
            currentItemLink = nil
            planetStore.walletTransactionMemo = ""
            NotificationCenter.default.post(name: .loadArticle, object: nil)
            switch planetStore.selectedView {
            case .followingPlanet(let followingPlanet):
                planetStore.walletTransactionMemo = "planet:\(followingPlanet.link)"
            default:
                break
            }
        }
        .onAppear {
            switch planetStore.selectedView {
            case .followingPlanet(let followingPlanet):
                planetStore.walletTransactionMemo = "planet:\(followingPlanet.link)"
            default:
                break
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Functions for the current selected planet
                toolbarPlanetView()
            }

            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                if let article = planetStore.selectedArticle {
                    Menu {
                        ArticleSetStarView(article: article)
                    } label: {
                        ArticleToolbarStarView(article: article)
                    }
                }

                if let article = planetStore.selectedArticle,
                    article.hasAudio
                {
                    toolbarAudioView(article: article)
                }

                // Menu for accessing the attachments if any
                if let article = planetStore.selectedArticle, let attachments = article.attachments,
                    attachments.count > 0
                {
                    toolbarAttachmentsView(article: article)
                }

                if let article = planetStore.selectedArticle as? MyArticleModel, !article.isAggregated() {
                    Button {
                        do {
                            try WriterStore.shared.editArticle(for: article)
                        }
                        catch {
                            PlanetStore.shared.alert(title: "Failed to launch writer")
                        }
                    } label: {
                        Image(systemName: "pencil.line")
                    }
                    .help("Edit Selected Article")
                    .keyboardShortcut("e", modifiers: [.command])
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                Button {
                    planetStore.isShowingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Search")
                .keyboardShortcut("f", modifiers: [.command])

                if let article = planetStore.selectedArticle {
                    Button {
                        isSharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .background(
                        SharingServicePicker(
                            isPresented: $isSharing,
                            sharingItems: [
                                sharingItem ?? URL(string: "https://planetable.eth.limo")!
                            ]
                        )
                    )
                    .help("Share Selected Article")
                }
            }
        }
    }

    private func canTip(planet: FollowingPlanetModel) -> String? {
        guard let walletAddress = planet.walletAddress else { return nil }
        debugPrint("Tipping: Following Planet \(walletAddress)")
        let myWalletAddress = planetStore.walletAddress
        debugPrint("Tipping: My Wallet \(myWalletAddress) / Author Wallet \(walletAddress)")
        if myWalletAddress.count == 42, myWalletAddress.lowercased() != walletAddress.lowercased() {
            return walletAddress
        }
        return nil
    }

    private func openInChromium(_ url: URL) {
        let supportedChromiumBrowsers = [
            "com.google.Chrome",
            "com.brave.Browser",
            "com.google.Chrome.canary",
        ]
        let appUrl: URL? = {
            for item in supportedChromiumBrowsers {
                if let found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item) {
                    return found
                }
            }
            return nil
        }()
        guard
            let appUrl = appUrl
        else {
            NSWorkspace.shared.open(url)
            return
        }

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: appUrl,
            configuration: self.openConfiguration(),
            completionHandler: nil
        )
    }

    private func openConfiguration() -> NSWorkspace.OpenConfiguration {
        let conf = NSWorkspace.OpenConfiguration()
        conf.hidesOthers = false
        conf.hides = false
        conf.activates = true
        return conf
    }

    @ViewBuilder
    private func toolbarAttachmentsView(article: ArticleModel) -> some View {
        if let attachments = article.attachments {
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

    @ViewBuilder
    private func toolbarAudioView(article: ArticleModel?) -> some View {
        if let myArticle = article as? MyArticleModel,
            let name = myArticle.audioFilename,
            let url = myArticle.getAttachmentURL(name: name)
        {
            Button {
                ArticleAudioPlayerViewModel.shared.url = url
                ArticleAudioPlayerViewModel.shared.title = myArticle.title
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
                ArticleAudioPlayerViewModel.shared.title = followingArticle.title
            } label: {
                Label("Play Audio", systemImage: "headphones")
            }
        }
    }

    @ViewBuilder
    private func toolbarPlanetView() -> some View {
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

            Button {
                planetStore.isShowingPlanetAvatarPicker = true
            } label: {
                Image(systemName: "face.smiling")
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
                    Image("custom.ethereum")
                }.help("Tip with Ethereum")
            }
            if planet.planetType == .ens {
                Button {
                    let url = URL(string: "https://app.ens.domains/name/\(planet.link)/details")
                    if let url = url {
                        openInChromium(url)
                    }
                } label: {
                    Image("custom.ens")
                }.help("Get ENS Info")
            }
            if let juiceboxEnabled = planet.juiceboxEnabled, juiceboxEnabled,
                planet.juiceboxProjectID != nil || planet.juiceboxProjectIDGoerli != nil
            {
                Button {
                    let url = planet.juiceboxURL()
                    if let url = url {
                        openInChromium(url)
                    }
                } label: {
                    Image("custom.juicebox")
                }.help("Visit Juicebox Project")
            }
        default:
            Text("")
        }
    }
}
