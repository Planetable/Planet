import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif


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
    @ObservedObject private var ipfsState = IPFSState.shared
    @ObservedObject private var speechPlayerViewModel = ArticleSpeechPlayerViewModel.shared
    @AppStorage(String.settingsAIIsReady) private var settingsAIIsReady: Bool = false
    @State private var isOnDeviceAIAvailable: Bool = false

    @State private var url: URL = Self.noSelectionURL
    @State private var isShowingAnalyticsPopover: Bool = false
    @State private var selectedAttachment: String? = nil

    @State private var isSharing: Bool = false
    @State private var aiChatResponseCount: Int = 0
    @State private var showLocalRendered: Bool = false
    @AppStorage(String.settingsReaderFontSize) private var readerFontSize: Double = 14

    @State private var readerFontSizeKeyMonitor: Any? = nil
    @State private var detectedSpeechLanguage: String? = nil
    @State private var isDetectingSpeechLanguage: Bool = false
    @State private var speechLanguageDetectionTask: Task<Void, Never>? = nil
    @State private var sharingItem: URL?
    @State private var currentItemHost: String? = nil
    @State private var currentItemLink: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ArticleWebView(url: $url)
            ArticleAudioPlayer()
            ArticleSpeechPlayer()
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
        .onChange(of: planetStore.selectedArticle) { _ in
            syncReaderViewPreference()
            syncSelectedArticlePresentation()
            refreshAIChatResponseCount()
            detectSpeechLanguage()
        }
        .onChange(of: planetStore.selectedView) { _ in
            if planetStore.selectedArticle == nil {
                syncReaderViewPreference()
                syncSelectedArticlePresentation()
            }
            refreshAIChatResponseCount()
        }
        .onChange(of: ipfsState.online) { online in
            handleIPFSOnlineChange(online)
        }
        .onAppear {
            syncReaderViewPreference()
            syncSelectedArticlePresentation()
            refreshAIChatResponseCount()
            checkOnDeviceAIAvailability()
            installReaderFontSizeKeyMonitor()
            detectSpeechLanguage()
        }
        .onDisappear {
            speechLanguageDetectionTask?.cancel()
            speechLanguageDetectionTask = nil
            removeReaderFontSizeKeyMonitor()
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Functions for the current selected planet
                toolbarPlanetView()
                toolbarArticlePlanetAvatarView()
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

                if (settingsAIIsReady || isOnDeviceAIAvailable), let article = planetStore.selectedArticle {
                    Button {
                        ArticleAIChatWindowManager.shared.open(for: article)
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
                    .help("Chat with AI about this article")
                }

                if let followingArticle = planetStore.selectedArticle as? FollowingArticleModel {
                    if followingArticle.supportsReaderView {
                        Button {
                            setReaderViewEnabled(!showLocalRendered, for: followingArticle.planet)
                            syncSelectedArticlePresentation()
                        } label: {
                            Image(systemName: showLocalRendered ? "globe" : "doc.richtext")
                        }
                        .help(showLocalRendered ? "Show Original Website" : "Show Reader View")
                    }

                    if followingArticle.supportsReadAloud {
                        Button {
                            toggleSpeechPlayback(for: followingArticle)
                        } label: {
                            Image(systemName: speechPlayerViewModel.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                        }
                        .disabled(detectedSpeechLanguage == nil)
                        .help(speechPlaybackHelpText())
                    }
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

    private func checkOnDeviceAIAvailability() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            if case .available = model.availability {
                isOnDeviceAIAvailable = true
                return
            }
        }
        #endif
        isOnDeviceAIAvailable = false
    }

    private func detectSpeechLanguage() {
        speechLanguageDetectionTask?.cancel()
        speechLanguageDetectionTask = nil
        detectedSpeechLanguage = nil
        isDetectingSpeechLanguage = false
        guard let followingArticle = planetStore.selectedArticle as? FollowingArticleModel,
            followingArticle.supportsReadAloud
        else { return }
        let text = followingArticle.title + " " + followingArticle.content
        isDetectingSpeechLanguage = true
        speechLanguageDetectionTask = Task.detached(priority: .utility) {
            let lang = ArticleSpeechPlayerViewModel.detectLanguage(of: text)
            let supported = lang.map { ArticleSpeechPlayerViewModel.hasVoices(forLanguage: $0) } ?? false
            guard !Task.isCancelled else { return }
            await MainActor.run {
                detectedSpeechLanguage = supported ? lang : nil
                isDetectingSpeechLanguage = false
                speechLanguageDetectionTask = nil
            }
        }
    }

    private func toggleSpeechPlayback(for article: FollowingArticleModel) {
        guard let language = detectedSpeechLanguage else { return }
        if speechPlayerViewModel.isSpeaking {
            speechPlayerViewModel.stop()
        } else {
            let text = ArticleSpeechPlayerViewModel.extractPlainText(from: article)
            speechPlayerViewModel.speak(text: text, title: article.title, language: language)
        }
    }

    private func speechPlaybackHelpText() -> String {
        if speechPlayerViewModel.isSpeaking {
            return "Stop Reading Aloud"
        }
        if detectedSpeechLanguage != nil {
            return "Read Aloud"
        }
        if isDetectingSpeechLanguage {
            return "Checking Read Aloud Availability"
        }
        return "Read Aloud Unavailable"
    }

    private func syncReaderViewPreference() {
        guard let followingArticle = planetStore.selectedArticle as? FollowingArticleModel,
            followingArticle.supportsReaderView
        else {
            showLocalRendered = false
            return
        }
        showLocalRendered = preferredReaderView(for: followingArticle.planet)
    }

    private func preferredReaderView(for planet: FollowingPlanetModel) -> Bool {
        let key = String.settingsPreferReaderView(forFollowingPlanetID: planet.id)
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }
        return defaults.bool(forKey: String.settingsPreferReaderView)
    }

    private func setReaderViewEnabled(_ enabled: Bool, for planet: FollowingPlanetModel) {
        let key = String.settingsPreferReaderView(forFollowingPlanetID: planet.id)
        UserDefaults.standard.set(enabled, forKey: key)
        showLocalRendered = enabled
    }

    private func installReaderFontSizeKeyMonitor() {
        guard readerFontSizeKeyMonitor == nil else { return }
        readerFontSizeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            guard event.modifierFlags.contains(.command),
                !event.modifierFlags.contains(.shift),
                !event.modifierFlags.contains(.option),
                showLocalRendered,
                planetStore.selectedArticle is FollowingArticleModel
            else { return event }
            switch event.charactersIgnoringModifiers {
            case "+", "=":
                readerFontSize = min(24, readerFontSize + 1)
                NotificationCenter.default.post(
                    name: .readerFontSizeChanged,
                    object: NSNumber(value: Int(readerFontSize))
                )
                return nil
            case "-":
                readerFontSize = max(10, readerFontSize - 1)
                NotificationCenter.default.post(
                    name: .readerFontSizeChanged,
                    object: NSNumber(value: Int(readerFontSize))
                )
                return nil
            case "0":
                readerFontSize = 14
                NotificationCenter.default.post(
                    name: .readerFontSizeChanged,
                    object: NSNumber(value: 14)
                )
                return nil
            default:
                return event
            }
        }
    }

    private func removeReaderFontSizeKeyMonitor() {
        if let monitor = readerFontSizeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            readerFontSizeKeyMonitor = nil
        }
    }

    private func refreshAIChatResponseCount() {
        guard let article = planetStore.selectedArticle,
            let chatFileURL = chatFileURL(for: article),
            let data = try? Data(contentsOf: chatFileURL)
        else {
            aiChatResponseCount = 0
            return
        }
        let persistedMessages: [ArticleAIChatPersistedMessage]
        if let envelope = try? JSONDecoder.shared.decode(ArticleAIChatPersistedData.self, from: data) {
            persistedMessages = envelope.messages
        } else if let legacy = try? JSONDecoder.shared.decode([ArticleAIChatPersistedMessage].self, from: data) {
            persistedMessages = legacy
        } else {
            aiChatResponseCount = 0
            return
        }
        aiChatResponseCount = persistedMessages.filter { $0.role == "assistant" }.count
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

    private func syncSelectedArticlePresentation() {
        currentItemHost = nil
        currentItemLink = nil
        sharingItem = nil
        planetStore.walletTransactionMemo = ""

        if let myArticle = planetStore.selectedArticle as? MyArticleModel {
            url = articleURL(for: myArticle)
            sharingItem = myArticle.browserURL?.absoluteURL
            currentItemLink = myArticle.link
        } else if let followingArticle = planetStore.selectedArticle as? FollowingArticleModel {
            if showLocalRendered, followingArticle.supportsReaderView,
                let localURL = try? followingArticle.renderLocalPreview(fontSize: CGFloat(readerFontSize))
            {
                url = localURL
            } else if let webviewURL = followingArticle.webviewURL {
                url = webviewURL
            } else {
                debugPrint("Failed to switch selected article - branch A")
                url = Self.noSelectionURL
            }
            sharingItem = followingArticle.browserURL?.absoluteURL
            currentItemLink = followingArticle.link
            if followingArticle.planet.planetType == .ens
                || followingArticle.planet.planetType == .dotbit
            {
                currentItemHost = followingArticle.planet.link
            }
        } else {
            debugPrint("Failed to switch selected article - branch B")
            url = Self.noSelectionURL
        }

        normalizeCurrentItemLink()

        if let host = currentItemHost {
            planetStore.walletTransactionMemo = "planet:\(host)"
            if let link = currentItemLink {
                planetStore.walletTransactionMemo = "planet:\(host)\(link)"
            }
        } else if case .followingPlanet(let followingPlanet) = planetStore.selectedView,
            planetStore.selectedArticle == nil
        {
            planetStore.walletTransactionMemo = "planet:\(followingPlanet.link)"
        }

        debugPrint("Current item link is \(currentItemLink ?? "nil")")
        debugPrint(
            "Current prepared transaction memo is \(planetStore.walletTransactionMemo)"
        )
    }

    private func handleIPFSOnlineChange(_ online: Bool) {
        guard online, planetStore.selectedArticle != nil else {
            return
        }

        let previousURL = url
        syncSelectedArticlePresentation()

        guard usesLocalGateway(url) else {
            return
        }
        guard previousURL == url else {
            return
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
    }

    private func usesLocalGateway(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost"
    }

    private func articleURL(for myArticle: MyArticleModel) -> URL {
        if myArticle.planet.templateName == "Croptop" {
            if FileManager.default.fileExists(atPath: myArticle.publicSimplePath.path) {
                let now = Date()
                let simpleHTMLAge = now.timeIntervalSince1970 - (
                    (try? FileManager.default.attributesOfItem(
                        atPath: myArticle.publicSimplePath.path
                    )[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                )
                if simpleHTMLAge < 7 {
                    return myArticle.publicSimplePath
                }
            }
            return myArticle.localPreviewURL ?? myArticle.publicIndexPath
        }

        // In future we can use the local gateway for all planets.
        return myArticle.publicIndexPath
    }

    private func normalizeCurrentItemLink() {
        guard let linkString = currentItemLink, !linkString.hasPrefix("/"),
            let linkURL = URL(string: linkString)
        else {
            return
        }

        var link = linkURL.path
        if let query = linkURL.query {
            link.append("?" + query)
        }
        if let fragment = linkURL.fragment {
            link.append("#" + fragment)
        }
        currentItemLink = link
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
    private func toolbarArticlePlanetAvatarView() -> some View {
        if let myArticle = planetStore.selectedArticle as? MyArticleModel,
            let articlePlanet = myArticle.planet
        {
            if case .myPlanet(let selectedPlanet) = planetStore.selectedView,
                selectedPlanet.id == articlePlanet.id
            {
                EmptyView()
            } else {
                Button {
                    let targetArticleID = myArticle.id
                    let targetPlanet = articlePlanet
                    planetStore.selectedView = .myPlanet(targetPlanet)
                    NotificationCenter.default.post(name: .scrollToSidebarItem, object: "sidebar-my-\(targetPlanet.id.uuidString)")
                    Task { @MainActor in
                        await restoreMyArticleSelection(
                            targetArticleID: targetArticleID,
                            targetPlanetID: targetPlanet.id
                        )
                    }
                } label: {
                    articlePlanet.avatarView(size: 20)
                }
                .help("Show \(articlePlanet.name)")
            }
        } else if let followingArticle = planetStore.selectedArticle as? FollowingArticleModel,
            let articlePlanet = followingArticle.planet
        {
            if case .followingPlanet(let selectedPlanet) = planetStore.selectedView,
                selectedPlanet.id == articlePlanet.id
            {
                EmptyView()
            } else {
                Button {
                    let targetArticleID = followingArticle.id
                    let targetPlanet = articlePlanet
                    planetStore.selectedView = .followingPlanet(targetPlanet)
                    NotificationCenter.default.post(name: .scrollToSidebarItem, object: "sidebar-following-\(targetPlanet.id.uuidString)")
                    Task { @MainActor in
                        await restoreFollowingArticleSelection(
                            targetArticleID: targetArticleID,
                            targetPlanetID: targetPlanet.id
                        )
                    }
                } label: {
                    articlePlanet.avatarView(size: 20)
                }
                .help("Show \(articlePlanet.name)")
            }
        }
    }

    @MainActor
    private func restoreMyArticleSelection(targetArticleID: UUID, targetPlanetID: UUID) async {
        // Wait briefly for selectedView didSet to refresh article list before restoring selection.
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard case .myPlanet(let selectedPlanet) = planetStore.selectedView,
            selectedPlanet.id == targetPlanetID
        else {
            return
        }
        if let article = planetStore.selectedArticleList?.first(where: { $0.id == targetArticleID })
            ?? selectedPlanet.articles.first(where: { $0.id == targetArticleID })
        {
            planetStore.selectedArticle = article
            Task(priority: .userInitiated) {
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
            }
        }
    }

    @MainActor
    private func restoreFollowingArticleSelection(targetArticleID: UUID, targetPlanetID: UUID) async {
        // Wait briefly for selectedView didSet to refresh article list before restoring selection.
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard case .followingPlanet(let selectedPlanet) = planetStore.selectedView,
            selectedPlanet.id == targetPlanetID
        else {
            return
        }
        if let article = planetStore.selectedArticleList?.first(where: { $0.id == targetArticleID })
            ?? selectedPlanet.articles.first(where: { $0.id == targetArticleID })
        {
            planetStore.selectedArticle = article
            Task(priority: .userInitiated) {
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
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
            EmptyView()
        }
    }
}
