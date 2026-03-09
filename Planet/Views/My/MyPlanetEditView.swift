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
    @State private var publishAsIPNS: Bool = true
    @State private var sshRsyncEnabled: Bool = false
    @State private var sshRsyncDestination: String
    @State private var sshRsyncKeyPath: String?
    @State private var sshRsyncDeleteEnabled: Bool = false

    @State private var cloudflarePagesEnabled: Bool = false
    @State private var cloudflarePagesAccountID: String
    @State private var cloudflarePagesAPIToken: String
    @State private var cloudflarePagesProjectName: String

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
        _publishAsIPNS = State(wrappedValue: planet.publishAsIPNS ?? true)
        _sshRsyncEnabled = State(wrappedValue: planet.sshRsyncEnabled ?? false)
        _sshRsyncDestination = State(wrappedValue: planet.sshRsyncDestination ?? "")
        _sshRsyncKeyPath = State(wrappedValue: planet.sshRsyncKeyPath)
        _sshRsyncDeleteEnabled = State(wrappedValue: planet.sshRsyncDeleteEnabled ?? false)
        _cloudflarePagesEnabled = State(wrappedValue: planet.cloudflarePagesEnabled ?? false)
        _cloudflarePagesAccountID = State(wrappedValue: planet.cloudflarePagesAccountID ?? "")
        _cloudflarePagesAPIToken = State(wrappedValue: planet.cloudflarePagesAPIToken ?? "")
        _cloudflarePagesProjectName = State(wrappedValue: planet.cloudflarePagesProjectName ?? "")
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
    private func publishingLinkRow(title: String, value: String, url: URL?) -> some View {
        let rowContent = HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .frame(width: CONTROL_CAPTION_WIDTH, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(url == nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if url != nil {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())

        if let url {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        }
        else {
            rowContent
        }
    }

    private func publishingHelpRow(_ text: String) -> some View {
        HStack {
            HStack {
                Spacer()
            }
            .frame(width: CONTROL_CAPTION_WIDTH + 10)

            Text(text)
                .lineLimit(3)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    @ViewBuilder
    private func publishingTab() -> some View {
        VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
            HStack {
                HStack {
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 10)

                Toggle("Publish as IPNS", isOn: $publishAsIPNS)
                    .toggleStyle(.checkbox)
                    .frame(alignment: .leading)

                Spacer()
            }

            publishingHelpRow(
                "When disabled, publish actions skip IPFS work and leave any existing IPNS or CID unchanged."
            )

            publishingLinkRow(
                title: "IPNS",
                value: planet.ipns,
                url: IPFSDaemon.urlForIPNS(planet.ipns)
            )

            publishingLinkRow(
                title: "CID",
                value: planet.lastPublishedCID ?? "Not published yet",
                url: planet.lastPublishedCID.flatMap { IPFSDaemon.urlForCID($0) }
            )

            Divider()
                .padding(.top, 6)
                .padding(.bottom, 6)

            HStack {
                HStack {
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 10)

                Toggle("Publish via SSH rsync", isOn: $sshRsyncEnabled)
                    .toggleStyle(.checkbox)
                    .frame(alignment: .leading)

                Spacer()
            }

            HStack {
                HStack {
                    Text("Address")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                TextField(
                    "",
                    text: $sshRsyncDestination,
                    prompt: Text("user@example.com:/www/example")
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                HStack {
                    Text("SSH Key")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                Text(sshRsyncKeyPath ?? "None (using ssh-agent)")
                    .foregroundColor(sshRsyncKeyPath != nil ? .primary : .secondary)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if sshRsyncKeyPath != nil {
                    Button("Clear") {
                        sshRsyncKeyPath = nil
                        try? FileManager.default.removeItem(at: planet.sshRsyncKeyStorePath)
                    }
                }

                Button("Select") {
                    selectSSHKey()
                }
            }

            publishingHelpRow(
                "Select a private key if ssh-agent is not available."
            )

            HStack {
                HStack {
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 10)

                Toggle("Delete extraneous files on destination", isOn: $sshRsyncDeleteEnabled)
                    .toggleStyle(.checkbox)
                    .frame(alignment: .leading)

                Spacer()
            }

            publishingHelpRow(
                "When enabled, files on the destination that are not in the source will be removed."
            )

            Divider()
                .padding(.top, 6)
                .padding(.bottom, 6)

            HStack {
                HStack {
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 10)

                Toggle("Publish via Cloudflare Pages", isOn: $cloudflarePagesEnabled)
                    .toggleStyle(.checkbox)
                    .frame(alignment: .leading)

                Spacer()
            }

            HStack {
                HStack {
                    Text("Account ID")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                TextField(
                    "",
                    text: $cloudflarePagesAccountID,
                    prompt: Text("Cloudflare Account ID")
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                HStack {
                    Text("API Token")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                SecureField(
                    "",
                    text: $cloudflarePagesAPIToken,
                    prompt: Text("Cloudflare API Token")
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                HStack {
                    Text("Project Name")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH)

                TextField(
                    "",
                    text: $cloudflarePagesProjectName,
                    prompt: Text("my-site")
                )
                .textFieldStyle(.roundedBorder)
            }

            publishingHelpRow(
                "The project will be created automatically if it doesn't exist. Use an API token with Cloudflare Pages Edit permission."
            )

            if let urlString = planet.cloudflarePagesLastDeployedURL,
               let url = URL(string: urlString) {
                publishingLinkRow(
                    title: "Pages URL",
                    value: url.absoluteString,
                    url: url
                )
            }
        }
        .padding(16)
        .tabItem {
            Text("Publishing")
        }
        .tag("publishing")
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
                    Image("custom.mastodon.fill")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("Mastodon")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $mastodonUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Image("custom.twitter")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("Twitter")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $twitterUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Image("custom.github")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("GitHub")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $githubUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Image("custom.telegram")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("Telegram")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $telegramUsername)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                HStack {
                    Image("custom.discord")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("Discord Link")
                    Spacer()
                }
                .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                TextField("", text: $discordLink)
                    .textFieldStyle(.roundedBorder)
            }

            if PlanetStore.app == .planet {
                Divider()
                    .padding(.top, 6)
                    .padding(.bottom, 6)

                juiceboxView()
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
        HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
            HStack {
                Spacer()
            }.frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)
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

        HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
            HStack {
                Image("custom.juicebox")
                Text("Project ID")
                Spacer()
            }
            .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

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

                    publishingTab()

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
                        planet.prewarmNewPost = prewarmNewPost
                        planet.publishAsIPNS = publishAsIPNS
                        planet.sshRsyncEnabled = sshRsyncEnabled
                        planet.sshRsyncDestination = MyPlanetModel.normalizedSSHRsyncDestination(
                            sshRsyncDestination
                        )
                        planet.sshRsyncKeyPath = sshRsyncKeyPath
                        planet.sshRsyncDeleteEnabled = sshRsyncDeleteEnabled
                        planet.cloudflarePagesEnabled = cloudflarePagesEnabled
                        planet.cloudflarePagesAccountID = cloudflarePagesAccountID.trim().isEmpty ? nil : cloudflarePagesAccountID.trim()
                        planet.cloudflarePagesAPIToken = cloudflarePagesAPIToken.trim().isEmpty ? nil : cloudflarePagesAPIToken.trim()
                        planet.cloudflarePagesProjectName = cloudflarePagesProjectName.trim().isEmpty ? nil : cloudflarePagesProjectName.trim()
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
    private func selectSSHKey() {
        let panel = NSOpenPanel()
        panel.title = "Select SSH Private Key"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let destination = planet.sshRsyncKeyStorePath
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            // Ensure the key file has strict permissions
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: destination.path
            )
            sshRsyncKeyPath = url.lastPathComponent
        }
        catch {
            showValidationAlert(
                title: "Failed to Import SSH Key",
                message: error.localizedDescription
            )
        }
    }

    private func showValidationAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

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
                showValidationAlert(
                    title: "Invalid Domain Name",
                    message: "Please enter a valid domain name. Do not include the protocol (http:// or https://) or any trailing slashes."
                )
            }
        }
        if sshRsyncEnabled {
            guard let destination = MyPlanetModel.normalizedSSHRsyncDestination(
                sshRsyncDestination
            ) else {
                errors += 1
                showValidationAlert(
                    title: "Missing SSH rsync Address",
                    message: "Enter a destination like user@example.com:/www/example before enabling SSH rsync publishing."
                )
                return errors
            }
            if !MyPlanetModel.isValidSSHRsyncDestination(destination) {
                errors += 1
                showValidationAlert(
                    title: "Invalid SSH rsync Address",
                    message: "Use the format user@example.com:/www/example."
                )
            }
        }
        if cloudflarePagesEnabled {
            if cloudflarePagesAccountID.trim().isEmpty
                || cloudflarePagesAPIToken.trim().isEmpty
                || cloudflarePagesProjectName.trim().isEmpty
            {
                errors += 1
                showValidationAlert(
                    title: "Incomplete Cloudflare Pages Settings",
                    message: "Account ID, API Token, and Project Name are all required when Cloudflare Pages publishing is enabled."
                )
            }
        }
        return errors
    }
}
