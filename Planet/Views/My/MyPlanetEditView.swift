import SwiftUI

struct MyPlanetEditView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 120
    let SOCIAL_CONTROL_CAPTION_WIDTH: CGFloat = 120

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore

    @ObservedObject var planet: MyPlanetModel

    @State private var selectedTab: String = "basic"

    @State private var name: String
    @State private var about: String
    @State private var domain: String
    @State private var authorName: String
    @State private var templateName: String
    @State private var saveRoundAvatar: Bool = false
    @State private var doNotIndex: Bool = false
    @State private var prewarmNewPost: Bool = true

    @State private var plausibleEnabled: Bool = false
    @State private var plausibleDomain: String
    @State private var plausibleAPIKey: String
    @State private var plausibleAPIServer: String = "plausible.io"

    @State private var twitterUsername: String
    @State private var githubUsername: String
    @State private var telegramUsername: String
    @State private var mastodonUsername: String
    @State private var discordLink: String

    /*
    @State private var dWebServicesEnabled: Bool = false
    @State private var dWebServicesDomain: String
    @State private var dWebServicesAPIKey: String
    */

    @State private var juiceboxEnabled: Bool = false
    @State private var juiceboxProjectID: String
    /* @State private var juiceboxProjectIDGoerli: String */

    @State private var pinnableEnabled: Bool = false
    @State private var pinnableAPIEndpoint: String
    @State private var pinnablePinCID: String? = nil
    @State private var pinnablePinStatus: PinnablePinStatus? = nil

    @State private var filebaseEnabled: Bool = false
    @State private var filebasePinName: String
    @State private var filebaseAPIToken: String

    @State private var filebasePinStatus: String? = nil
    @State private var filebasePinStatusMessage: String? = nil
    @State private var filebasePinCID: String? = nil

    // Template Settings
    @State private var currentSettings: [String: String] = [:]
    @State private var userSettings: [String: String] = [:]

    // Highlight Color (Currently only for Croptop)
    @State private var selectedColor: Color = Color(hex: "#F056C1")

    init(planet: MyPlanetModel) {
        self.planet = planet
        _name = State(wrappedValue: planet.name)
        _about = State(wrappedValue: planet.about)
        _domain = State(wrappedValue: planet.domain ?? "")
        _authorName = State(wrappedValue: planet.authorName ?? "")
        _templateName = State(wrappedValue: planet.templateName)
        _saveRoundAvatar = State(wrappedValue: planet.saveRoundAvatar ?? false)
        _doNotIndex = State(wrappedValue: planet.doNotIndex ?? false)
        _prewarmNewPost = State(wrappedValue: planet.prewarmNewPost ?? true)
        _plausibleEnabled = State(wrappedValue: planet.plausibleEnabled ?? false)
        _plausibleDomain = State(wrappedValue: planet.plausibleDomain ?? "")
        _plausibleAPIKey = State(wrappedValue: planet.plausibleAPIKey ?? "")
        _plausibleAPIServer = State(wrappedValue: planet.plausibleAPIServer ?? "plausible.io")
        _twitterUsername = State(wrappedValue: planet.twitterUsername ?? "")
        _githubUsername = State(wrappedValue: planet.githubUsername ?? "")
        _telegramUsername = State(wrappedValue: planet.telegramUsername ?? "")
        _mastodonUsername = State(wrappedValue: planet.mastodonUsername ?? "")
        _discordLink = State(wrappedValue: planet.discordLink ?? "")
        /*
        _dWebServicesEnabled = State(wrappedValue: planet.dWebServicesEnabled ?? false)
        _dWebServicesDomain = State(wrappedValue: planet.dWebServicesDomain ?? "")
        _dWebServicesAPIKey = State(wrappedValue: planet.dWebServicesAPIKey ?? "")
        */
        _juiceboxEnabled = State(wrappedValue: planet.juiceboxEnabled ?? false)
        _juiceboxProjectID = State(wrappedValue: planet.juiceboxProjectID?.stringValue() ?? "")
        /*
        _juiceboxProjectIDGoerli = State(
            wrappedValue: planet.juiceboxProjectIDGoerli?.stringValue() ?? ""
        )
        */
        _pinnableEnabled = State(wrappedValue: planet.pinnableEnabled ?? false)
        _pinnableAPIEndpoint = State(wrappedValue: planet.pinnableAPIEndpoint ?? "")
        _pinnablePinCID = State(wrappedValue: planet.pinnablePinCID ?? nil)
        _filebaseEnabled = State(wrappedValue: planet.filebaseEnabled ?? false)
        _filebasePinName = State(wrappedValue: planet.filebasePinName ?? "")
        _filebaseAPIToken = State(wrappedValue: planet.filebaseAPIToken ?? "")
    }

    @ViewBuilder
    private func analyticsTab() -> some View {
        VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
            HStack {
                HStack {
                    Spacer()
                }.frame(width: CONTROL_CAPTION_WIDTH + 10)
                Toggle(
                    "Enable Plausible for Traffic Analytics",
                    isOn: $plausibleEnabled
                )
                .toggleStyle(.checkbox)
                .frame(alignment: .leading)
                Spacer()
            }

            HStack {
                HStack {
                    Text("Domain")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                TextField("", text: $plausibleDomain)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                HStack {
                    Text("API Key")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                SecureField("", text: $plausibleAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                HStack {
                    Text("API Server")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                TextField("", text: $plausibleAPIServer)
                    .textFieldStyle(.roundedBorder)
            }

        }
        .padding(16)
        .tabItem {
            Text("Analytics")
        }
        .tag("analytics")
    }

    @ViewBuilder
    private func socialTab() -> some View {
        VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Text("Mastodon")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $mastodonUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Text("Twitter")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $twitterUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Text("GitHub")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $githubUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Text("Telegram")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $telegramUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Text("Discord Link")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $discordLink)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
        .tabItem {
            Text("Social")
        }
        .tag("social")
    }

    @ViewBuilder
    private func pinnableView() -> some View {
        HStack {
            HStack {
                Spacer()
            }.frame(width: CONTROL_CAPTION_WIDTH + 20 + 10)
            Toggle("Enable Pinnable for Pinning", isOn: $pinnableEnabled)
                .toggleStyle(.checkbox)
                .frame(alignment: .leading)
            Spacer()
        }

        HStack {
            HStack {
                Text("API Endpoint")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 20)

            TextField("", text: $pinnableAPIEndpoint)
                .textFieldStyle(.roundedBorder)
        }

        HStack {
            HStack {
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 20)

            Text(
                "You can get your API endpoint after you have added this site to [Pinnable](https://pinnable.xyz)."
            )
            .lineLimit(2)
            .font(.footnote)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let enabled = planet.pinnableEnabled, enabled {
            HStack {
                HStack {
                    Text("Pin Status")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 20)

                if let _ = pinnablePinStatus {
                    Button {
                        if let url = planet.browserURL {
                            debugPrint("Pinnable: Open preview URL \(url)")
                            NSWorkspace.shared.open(url)
                        }
                        else {
                            debugPrint("Pinnable: Preview URL is not available")
                        }
                    } label: {
                        if let cid = pinnablePinCID {
                            if cid == planet.lastPublishedCID {
                                Label("Pinned", systemImage: "checkmark.circle.fill")
                            }
                            else {
                                Label("Pinning", systemImage: "ellipsis")
                            }
                        }
                        else {
                            Label("Error", systemImage: "exclamationmark.triangle.fill")
                        }
                    }

                    Spacer()
                }
                else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }.onAppear {
                Task {
                    if let status = await planet.checkPinnablePinStatus() {
                        pinnablePinStatus = status
                        if let cid = status.last_known_cid {
                            pinnablePinCID = cid
                            if cid != planet.pinnablePinCID {
                                planet.pinnablePinCID = cid
                                try? planet.save()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func filebaseView() -> some View {
        HStack {
            HStack {
                Spacer()
            }.frame(width: CONTROL_CAPTION_WIDTH + 20 + 10)
            Toggle("Enable Filebase for Pinning", isOn: $filebaseEnabled)
                .toggleStyle(.checkbox)
                .frame(alignment: .leading)
            Spacer()
        }

        HStack {
            HStack {
                Text("Pin Name")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 20)

            TextField("", text: $filebasePinName)
                .textFieldStyle(.roundedBorder)
        }

        HStack {
            HStack {
                Text("API Token")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 20)

            SecureField("", text: $filebaseAPIToken)
                .textFieldStyle(.roundedBorder)
        }

        if let requestID = planet.filebaseRequestID {
            HStack {
                HStack {
                    Text("Request ID")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 20)

                Text(requestID).font(.footnote)

                Spacer()
            }
        }

        if let hasFilebase = planet.filebaseEnabled, hasFilebase {
            HStack {
                HStack {
                    Text("Pin Status")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 20)

                if let pinStatus = filebasePinStatus {
                    Button {
                        if let cid = filebasePinCID,
                            let url = URL(
                                string: "https://ipfs.filebase.io/ipfs/\(cid)"
                            )
                        {
                            debugPrint("Filebase: Open preview URL \(url)")
                            NSWorkspace.shared.open(url)
                        }
                        else {
                            debugPrint("Filebase: Preview URL is not available")
                        }
                    } label: {
                        switch pinStatus {
                        case "pinned":
                            Label(
                                pinStatus.capitalized,
                                systemImage: "checkmark.circle.fill"
                            )
                        case "pinning":
                            Label(
                                pinStatus.capitalized,
                                systemImage: "ellipsis.circle.fill"
                            )
                        case "queued":
                            Label(
                                pinStatus.capitalized,
                                systemImage: "hourglass.bottomhalf.filled"
                            )
                        default:
                            Label(
                                pinStatus.capitalized,
                                systemImage: "questionmark.circle"
                            )
                        }
                    }

                    if let message = filebasePinStatusMessage {
                        Button {
                            NSWorkspace.shared.open(
                                URL(string: "https://console.filebase.com/keys")!
                            )
                        } label: {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                        }.buttonStyle(.link)
                    }

                    Spacer()
                }
                else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }.onAppear {
                Task {
                    if let filebaseEnabled = planet.filebaseEnabled,
                        filebaseEnabled,
                        let filebasePinName = planet.filebasePinName,
                        let filebaseAPIToken = planet.filebaseAPIToken,
                        let filebaseRequestID = planet.filebaseRequestID
                    {
                        let filebase = Filebase(
                            pinName: filebasePinName,
                            apiToken: filebaseAPIToken
                        )
                        let (pin, message) = await filebase.checkPinStatus(
                            requestID: filebaseRequestID
                        )
                        if let pin = pin {
                            filebasePinStatus = pin.status
                            filebasePinCID = pin.cid
                        }
                        else {
                            filebasePinStatus = "Unknown"
                            if let message = message {
                                filebasePinStatusMessage = message
                            }
                        }
                    }
                }
            }
        }
    }


    @ViewBuilder
    private func juiceboxView() -> some View {
        HStack {
            HStack {
                Spacer()
            }.frame(width: CONTROL_CAPTION_WIDTH + 40 + 10)
            Toggle("Enable Juicebox Integration", isOn: $juiceboxEnabled)
                .toggleStyle(.checkbox)
                .frame(alignment: .leading)
            Spacer()
            HelpLinkButton(
                helpLink: URL(
                    string: "https://www.planetable.xyz/guides/juicebox/"
                )!
            )
        }

        HStack {
            HStack {
                Image("custom.juicebox")
                Text("Project ID")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 40)

            TextField("", text: $juiceboxProjectID)
                .textFieldStyle(.roundedBorder)
        }

        /*
        HStack {
            HStack {
                Text("Project ID (Goerli)")
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 20)

            TextField("", text: $juiceboxProjectIDGoerli)
                .textFieldStyle(.roundedBorder)
        }
        */
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {

                HStack(spacing: 10) {
                    planet.smallAvatarAndNameView()
                    Spacer()
                }

                TabView(selection: $selectedTab) {
                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 10)

                            ArtworkView(
                                image: planet.avatar,
                                planetNameInitials: planet.nameInitials,
                                planetID: planet.id,
                                cornerRadius: 40,
                                size: CGSize(width: 80, height: 80),
                                uploadAction: { url in
                                    do {
                                        try planet.updateAvatar(path: url)
                                    }
                                    catch {
                                        debugPrint("failed to upload planet avatar: \(error)")
                                    }
                                },
                                deleteAction: {
                                    do {
                                        try planet.removeAvatar()
                                    }
                                    catch {
                                        debugPrint("failed to remove planet avatar: \(error)")
                                    }
                                }
                            )
                            .padding(.top, 0)
                            .padding(.bottom, 10)

                            Spacer()
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 10)
                            Toggle("Save circularized avatar image on disk", isOn: $saveRoundAvatar)
                                .toggleStyle(.checkbox)
                                .frame(alignment: .leading)
                            Spacer()
                        }

                        HStack {
                            HStack {
                                Text("Site Name")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextField("", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            HStack {
                                Text("Domain")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextField("", text: $domain, prompt: Text("example.eth"))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 10)

                            Text(
                                "This domain will be used in places that need a domain prefix, like for RSS or Podcast feeds."
                            )
                            .lineLimit(2)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 10)
                            Toggle("Ask search engine not to index the site", isOn: $doNotIndex)
                                .toggleStyle(.checkbox)
                                .frame(alignment: .leading)
                            Spacer()
                        }

                        HStack {
                            HStack {
                                Text("About")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextEditor(text: $about)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .lineSpacing(2)
                                .disableAutocorrection(true)
                                .cornerRadius(6)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                )
                        }

                        if PlanetStore.app == .planet {
                            HStack {
                                HStack {
                                    Text("Author Name")
                                    Spacer()
                                }
                                .frame(width: CONTROL_CAPTION_WIDTH)

                                TextField("", text: $authorName)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if PlanetStore.app == .planet
                            || ($templateName.wrappedValue != "Croptop" && PlanetStore.app == .lite)
                        {
                            Picker(selection: $templateName) {
                                ForEach(TemplateStore.shared.templates) { template in
                                    Text(template.name)
                                        .tag(template.name)
                                }
                            } label: {
                                HStack {
                                    Text("Template")
                                    Spacer()
                                }
                                .frame(width: CONTROL_CAPTION_WIDTH)
                            }
                            .pickerStyle(.menu)
                        }

                        if PlanetStore.app == .lite {
                            HStack {
                                HStack {
                                    Text("Highlight Color")
                                    Spacer()
                                }
                                .frame(width: CONTROL_CAPTION_WIDTH - 10)

                                ColorPicker("", selection: $selectedColor)
                                    .onChange(of: selectedColor) { color in
                                        let hex = color.toHexValue()
                                        userSettings["highlightColor"] = hex
                                    }

                                Spacer()
                            }
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 10)
                            Toggle("Prewarm new post on public gateways", isOn: $prewarmNewPost)
                                .toggleStyle(.checkbox)
                                .frame(alignment: .leading)
                            Spacer()
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Basic Info")
                    }
                    .tag("basic")

                    analyticsTab()

                    if PlanetStore.app == .planet {
                        socialTab()
                    }

                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        pinnableView()

                        if PlanetStore.app == .planet {
                            Divider()
                                .padding(.top, 6)
                                .padding(.bottom, 6)

                            filebaseView()
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Pinning")
                    }
                    .tag("pinning")

                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        if PlanetStore.app == .planet {
                            juiceboxView()

                            /*
                            Divider()
                                .padding(.top, 6)
                                .padding(.bottom, 6)
                            */
                        }

                        /*
                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 20 + 10)
                            Toggle("Enable dWebServices.xyz for IPNS", isOn: $dWebServicesEnabled)
                                .toggleStyle(.checkbox)
                                .frame(alignment: .leading)
                            Spacer()
                            HelpLinkButton(
                                helpLink: URL(
                                    string: "https://www.planetable.xyz/guides/dweb-services-xyz/"
                                )!
                            )
                        }

                        HStack {
                            HStack {
                                Text("Domain")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 20)

                            TextField("", text: $dWebServicesDomain)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            HStack {
                                Text("API Key")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 20)

                            SecureField("", text: $dWebServicesAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        */
                    }
                    .padding(16)
                    .tabItem {
                        Text("Integrations")
                    }
                    .tag("integrations")
                }

                HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(width: 50)
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button {
                        if verifyUserInput() > 0 {
                            return
                        }
                        if !name.trim().isEmpty {
                            planet.name = name.trim()
                        }
                        var resaveAvatar = false
                        planet.about = about.trim()
                        planet.domain = domain.trim()
                        if planet.authorName != authorName {
                            if authorName == "" {
                                planet.authorName = nil
                            }
                            else {
                                planet.authorName = authorName.trim()
                            }
                        }
                        planet.templateName = templateName
                        if planet.saveRoundAvatar != saveRoundAvatar {
                            planet.saveRoundAvatar = saveRoundAvatar
                            if saveRoundAvatar {
                                // Read the avatar file on disk and resave it
                                if let _ = planet.avatar {
                                    resaveAvatar = true
                                }
                            }
                        }
                        planet.doNotIndex = doNotIndex
                        planet.plausibleEnabled = plausibleEnabled
                        planet.plausibleDomain = plausibleDomain.trim()
                        planet.plausibleAPIKey = plausibleAPIKey
                        planet.plausibleAPIServer = plausibleAPIServer
                        planet.twitterUsername = twitterUsername.sanitized().trim()
                        planet.githubUsername = githubUsername.sanitized().trim()
                        planet.telegramUsername = telegramUsername.sanitized().trim()
                        planet.mastodonUsername = mastodonUsername.sanitized().trim()
                        planet.discordLink = discordLink.trim()
                        /*
                        planet.dWebServicesEnabled = dWebServicesEnabled
                        planet.dWebServicesDomain = dWebServicesDomain
                        planet.dWebServicesAPIKey = dWebServicesAPIKey
                        */
                        planet.juiceboxEnabled = juiceboxEnabled
                        planet.juiceboxProjectID = Int(juiceboxProjectID)
                        /* planet.juiceboxProjectIDGoerli = Int(juiceboxProjectIDGoerli) */
                        planet.pinnableEnabled = pinnableEnabled
                        planet.pinnableAPIEndpoint = pinnableAPIEndpoint
                        planet.filebaseEnabled = filebaseEnabled
                        planet.filebasePinName = filebasePinName
                        planet.filebaseAPIToken = filebaseAPIToken
                        Task {
                            planet.updateTemplateSettings(settings: userSettings)
                            try planet.save()
                            if resaveAvatar {
                                Task.detached {
                                    do {
                                        try await planet.updateAvatar(path: planet.publicAvatarPath)
                                    }
                                    catch {
                                        debugPrint("failed to save circularized avatar image: \(error)")
                                    }
                                }
                            }
                            Task(priority: .background) {
                                try await planet.rebuild()
                            }
                            NotificationCenter.default.post(name: .loadArticle, object: nil)
                        }
                        dismiss()
                    } label: {
                        Text("OK")
                            .frame(width: 50)
                    }
                    .disabled(name.isEmpty)
                }
            }.padding(PlanetUI.SHEET_PADDING)
        }
        .padding(0)
        .frame(width: 520, height: nil, alignment: .top)
        .onAppear {
            currentSettings = planet.templateSettings()
            for (key, value) in currentSettings {
                userSettings[key] = value
                if key == "highlightColor" {
                    selectedColor = Color(hex: value)
                }
            }
        }
    }
}

extension MyPlanetEditView {
    func verifyUserInput() -> Int {
        var errors: Int = 0
        // TODO: Better sanity check goes here
        if domain.trim().count > 0 {
            // Use regular expression to check if the domain is valid
            let regex = try! NSRegularExpression(
                pattern: "^[a-z0-9]+([\\-\\.]{1}[a-z0-9]+)*\\.[a-z]{2,5}$",
                options: .caseInsensitive
            )
            let range = NSRange(location: 0, length: domain.trim().count)
            if regex.firstMatch(in: domain.trim(), options: [], range: range) == nil {
                errors += 1

                let alert = NSAlert()
                alert.messageText = "Invalid Domain Name"
                alert.informativeText =
                    "Please enter a valid domain name. Do not include the protocol (http:// or https://) or any trailing slashes."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        return errors
    }
}
