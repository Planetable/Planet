import SwiftUI


struct PlanetRebuildView: View {
    @ObservedObject var planet: MyPlanetModel

    var body: some View {
        if planet.needsRebuild {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Text("Build the site to publish the latest changes")

                    Spacer()

                    Button {
                        Task(priority: .userInitiated) {
                            PlanetStore.shared.selectedView = .myPlanet(planet)
                            do {
                                try await planet.rebuild()
                            }
                            catch {
                                DispatchQueue.main.async {
                                    PlanetStore.shared.isShowingAlert = true
                                    PlanetStore.shared.alertTitle = "Failed to Rebuild Planet"
                                    PlanetStore.shared.alertMessage = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                        Text("Full Rebuild")
                    }

                    Button {
                        Task(priority: .userInitiated) {
                            PlanetStore.shared.selectedView = .myPlanet(planet)
                            do {
                                try await planet.quickRebuild()
                            }
                            catch {
                                Task { @MainActor in
                                    PlanetStore.shared.isShowingAlert = true
                                    PlanetStore.shared.alertTitle = "Failed to Quick Rebuild Planet"
                                    PlanetStore.shared.alertMessage = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "bolt.fill")
                        Text("Quick Rebuild")
                    }
                }.padding(8)
            }
        }
    }
}

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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
                Task.detached {
                    await PlanetStore.shared.updateTotalStarredCount()
                }
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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
            Task.detached {
                await PlanetStore.shared.updateTotalStarredCount()
            }
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
    @AppStorage(String.settingsAIIsReady) private var settingsAIIsReady: Bool = false

    @State private var url: URL = Self.noSelectionURL
    @State private var isShowingAnalyticsPopover: Bool = false
    @State private var selectedAttachment: String? = nil

    @State private var isSharing: Bool = false
    @State private var isShowingAIChat: Bool = false
    @State private var aiChatResponseCount: Int = 0

    @State private var sharingItem: URL?
    @State private var currentItemHost: String? = nil
    @State private var currentItemLink: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ArticleWebView(url: $url)
            ArticleAudioPlayer()
            if let article = planetStore.selectedArticle, let myArticle = article as? MyArticleModel, let planet = myArticle.planet {
                PlanetRebuildView(planet: planet)
            }
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
            refreshAIChatResponseCount()
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
            refreshAIChatResponseCount()
        }
        .onAppear {
            switch planetStore.selectedView {
            case .followingPlanet(let followingPlanet):
                planetStore.walletTransactionMemo = "planet:\(followingPlanet.link)"
            default:
                break
            }
            refreshAIChatResponseCount()
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

                if settingsAIIsReady, planetStore.selectedArticle != nil {
                    Button {
                        isShowingAIChat = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            if aiChatResponseCount > 0 {
                                Text("\(aiChatResponseCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Chat with AI about this article")
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

                if let _ = planetStore.selectedArticle {
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
        .sheet(isPresented: $isShowingAIChat, onDismiss: {
            refreshAIChatResponseCount()
        }) {
            if let article = planetStore.selectedArticle {
                ArticleAIChatView(article: article)
            } else {
                Text("No article selected")
                    .frame(width: 420, height: 260)
            }
        }
    }

    private func chatFileURL(for article: ArticleModel) -> URL? {
        if let myArticle = article as? MyArticleModel {
            return myArticle.path.deletingLastPathComponent().appendingPathComponent(
                "\(myArticle.id.uuidString)-chats.json"
            )
        }
        if let followingArticle = article as? FollowingArticleModel {
            return followingArticle.path.deletingLastPathComponent().appendingPathComponent(
                "\(followingArticle.id.uuidString)-chats.json"
            )
        }
        return nil
    }

    private func refreshAIChatResponseCount() {
        guard let article = planetStore.selectedArticle,
            let chatFileURL = chatFileURL(for: article),
            let data = try? Data(contentsOf: chatFileURL),
            let persisted = try? JSONDecoder.shared.decode([ArticleAIChatPersistedMessage].self, from: data)
        else {
            aiChatResponseCount = 0
            return
        }
        aiChatResponseCount = persisted.filter { $0.role == "assistant" }.count
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

            Button {
                PlanetStore.shared.isQuickPosting = true
            } label: {
                Image(systemName: "plus.bubble")
            }
            .keyboardShortcut("d", modifiers: [.command])
            .help("Quick Post")

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
            if let _ = canTip(planet: planet) {
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

private struct ArticleAIChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let tokenUsage: String?
}

private struct ArticleAIChatPersistedMessage: Codable {
    let role: String
    let content: String
    let tokenUsage: String?
}

private struct ArticleAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var article: ArticleModel

    @State private var messages: [ArticleAIChatMessage] = []
    @State private var apiMessages: [[String: String]] = []
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorText: String? = nil
    @State private var shouldAnimateScroll: Bool = false
    @State private var chatFontSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("AI Research Chat", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                }
                ControlGroup {
                    Button {
                        chatFontSize = max(12, chatFontSize - 1)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                    }
                    .disabled(chatFontSize <= 12)
                    .help("Decrease Font Size")
                    Button {
                        chatFontSize = min(20, chatFontSize + 1)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                    }
                    .disabled(chatFontSize >= 20)
                    .help("Increase Font Size")
                }
                .frame(width: 74)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16, alignment: .center)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Context loaded from: \(contextTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(messages) { message in
                            HStack(alignment: .top) {
                                Text(message.role == "assistant" ? "AI" : "You")
                                    .font(.system(size: chatFontSize))
                                    .lineSpacing(5)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, message.role == "assistant" ? 0 : 8)
                                    .frame(width: 34, alignment: .leading)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(message.content)
                                        .font(.system(size: chatFontSize))
                                        .lineSpacing(5)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: message.role == "user" ? nil : .infinity, alignment: .leading)
                                    if message.role == "assistant", let tokenUsage = message.tokenUsage {
                                        Text(tokenUsage)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(message.role == "user" ? 8 : 0)
                                .background(
                                    message.role == "user"
                                        ? Color("BorderColor").opacity(0.5)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .id(message.id)
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { _ in
                    if let lastID = messages.last?.id {
                        if shouldAnimateScroll {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        } else {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                chatInputField()

                Button("Send") {
                    sendMessage()
                }
                .disabled(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(12)
        }
        .frame(width: 720, height: 520)
        .onAppear {
            loadPersistedChat()
            prepareInitialContextIfNeeded()
            Task { @MainActor in
                shouldAnimateScroll = true
            }
        }
    }

    @ViewBuilder
    private func chatInputField() -> some View {
        if #available(macOS 13.0, *) {
            TextField("Ask about this article…", text: $inputText, axis: .vertical)
                .lineLimit(1 ... 6)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage()
                }
                .disabled(isSending)
        } else {
            TextField("Ask about this article…", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage()
                }
                .disabled(isSending)
        }
    }

    private func prepareInitialContextIfNeeded() {
        guard apiMessages.isEmpty else { return }
        let systemPrompt = "You are a useful research assistant. Return only essential information. No small talk, no preambles like \"here is\", and do not ask follow-up questions at the end."
        let articleContext = """
        You are helping with the following article.

        Title: \(article.title)

        Content:
        \(article.content)
        """
        apiMessages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": articleContext],
        ]
    }

    private var chatFileURL: URL? {
        if let myArticle = article as? MyArticleModel {
            return myArticle.path.deletingLastPathComponent().appendingPathComponent("\(myArticle.id.uuidString)-chats.json")
        }
        if let followingArticle = article as? FollowingArticleModel {
            return followingArticle.path.deletingLastPathComponent().appendingPathComponent("\(followingArticle.id.uuidString)-chats.json")
        }
        return nil
    }

    private func loadPersistedChat() {
        guard let chatFileURL else { return }
        guard let data = try? Data(contentsOf: chatFileURL) else { return }
        guard let persisted = try? JSONDecoder.shared.decode([ArticleAIChatPersistedMessage].self, from: data) else {
            return
        }

        messages = persisted.map { item in
            ArticleAIChatMessage(role: item.role, content: item.content, tokenUsage: item.tokenUsage)
        }
        let systemPrompt = "You are a useful research assistant. Return only essential information. No small talk, no preambles like \"here is\", and do not ask follow-up questions at the end."
        let articleContext = """
        You are helping with the following article.

        Title: \(article.title)

        Content:
        \(article.content)
        """
        apiMessages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": articleContext],
        ] + persisted.map { item in
            ["role": item.role, "content": item.content]
        }
    }

    private func persistChat() {
        guard let chatFileURL else { return }
        let persisted = messages.map { item in
            ArticleAIChatPersistedMessage(role: item.role, content: item.content, tokenUsage: item.tokenUsage)
        }
        guard let data = try? JSONEncoder.shared.encode(persisted) else { return }
        try? data.write(to: chatFileURL)
    }

    private var contextTitle: String {
        let title = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }

        let content = article.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            return "Untitled Article"
        }

        if let range = content.range(of: #"[.!?](\s|$)"#, options: .regularExpression) {
            let sentence = String(content[..<range.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                return sentence
            }
        }

        if let firstLine = content.split(whereSeparator: \.isNewline).first {
            let line = String(firstLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                return line
            }
        }

        return content
    }

    private func sendMessage() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        inputText = ""
        errorText = nil
        messages.append(ArticleAIChatMessage(role: "user", content: prompt, tokenUsage: nil))
        apiMessages.append(["role": "user", "content": prompt])
        persistChat()
        isSending = true

        Task {
            do {
                let (reply, tokenUsage) = try await requestReply(messages: apiMessages)
                await MainActor.run {
                    messages.append(ArticleAIChatMessage(role: "assistant", content: reply, tokenUsage: tokenUsage))
                    apiMessages.append(["role": "assistant", "content": reply])
                    persistChat()
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isSending = false
                }
            }
        }
    }

    private func requestReply(messages: [[String: String]]) async throws -> (String, String?) {
        let base = UserDefaults.standard.string(forKey: .settingsAIAPIBase)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = UserDefaults.standard.string(forKey: .settingsAIPreferredModel) ?? "claude-sonnet-4-6"
        guard !base.isEmpty else {
            throw NSError(domain: "ArticleAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI API base URL is not configured"])
        }
        guard let url = URL(string: base.hasSuffix("/") ? "\(base)chat/completions" : "\(base)/chat/completions") else {
            throw NSError(domain: "ArticleAIChat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid AI API base URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try? KeychainHelper.shared.loadValue(forKey: .settingsAIAPIToken), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": messages.map { message in
                [
                    "role": message["role"] ?? "user",
                    "content": message["content"] ?? "",
                ]
            },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ArticleAIChat", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid AI API response"])
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ArticleAIChat", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "AI API error \(http.statusCode): \(body)"])
        }
        return try parseAssistantReply(data: data)
    }

    private func parseAssistantReply(data: Data) throws -> (String, String?) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            throw NSError(domain: "ArticleAIChat", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected AI response format"])
        }

        let tokenUsage: String? = {
            let modelName = json["model"] as? String
            guard let usage = json["usage"] as? [String: Any] else { return nil }
            let promptTokens = usage["prompt_tokens"] as? Int
            let completionTokens = usage["completion_tokens"] as? Int
            let totalTokens = usage["total_tokens"] as? Int
            var parts: [String] = [
                promptTokens != nil ? "Prompt: \(promptTokens!)" : nil,
                completionTokens != nil ? "Completion: \(completionTokens!)" : nil,
                totalTokens != nil ? "Total: \(totalTokens!)" : nil,
            ].compactMap { $0 }
            if let modelName, !modelName.isEmpty {
                parts.insert("Model: \(modelName)", at: 0)
            }
            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: " • ")
        }()

        if let content = message["content"] as? String {
            return (content, tokenUsage)
        }
        if let contentParts = message["content"] as? [[String: Any]] {
            let text = contentParts
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return (text, tokenUsage)
            }
        }
        throw NSError(domain: "ArticleAIChat", code: 5, userInfo: [NSLocalizedDescriptionKey: "AI response did not include content"])
    }
}
