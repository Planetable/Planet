import SwiftUI

struct MyPlanetEditView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 100
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

    @State private var plausibleEnabled: Bool = false
    @State private var plausibleDomain: String
    @State private var plausibleAPIKey: String
    @State private var plausibleAPIServer: String = "plausible.io"

    @State private var twitterUsername: String
    @State private var githubUsername: String
    @State private var telegramUsername: String
    @State private var mastodonUsername: String

    @State private var dWebServicesEnabled: Bool = false
    @State private var dWebServicesDomain: String
    @State private var dWebServicesAPIKey: String

    @State private var juiceboxEnabled: Bool = false
    @State private var juiceboxProjectID: String
    @State private var juiceboxProjectIDGoerli: String

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
    
    static let isCroptop: Bool = ProcessInfo.processInfo.environment["TARGET_NAME"] == "Croptop"

    init(planet: MyPlanetModel) {
        self.planet = planet
        _name = State(wrappedValue: planet.name)
        _about = State(wrappedValue: planet.about)
        _domain = State(wrappedValue: planet.domain ?? "")
        _authorName = State(wrappedValue: planet.authorName ?? "")
        _templateName = State(wrappedValue: planet.templateName)
        _plausibleEnabled = State(wrappedValue: planet.plausibleEnabled ?? false)
        _plausibleDomain = State(wrappedValue: planet.plausibleDomain ?? "")
        _plausibleAPIKey = State(wrappedValue: planet.plausibleAPIKey ?? "")
        _plausibleAPIServer = State(wrappedValue: planet.plausibleAPIServer ?? "plausible.io")
        _twitterUsername = State(wrappedValue: planet.twitterUsername ?? "")
        _githubUsername = State(wrappedValue: planet.githubUsername ?? "")
        _telegramUsername = State(wrappedValue: planet.telegramUsername ?? "")
        _mastodonUsername = State(wrappedValue: planet.mastodonUsername ?? "")
        _dWebServicesEnabled = State(wrappedValue: planet.dWebServicesEnabled ?? false)
        _dWebServicesDomain = State(wrappedValue: planet.dWebServicesDomain ?? "")
        _dWebServicesAPIKey = State(wrappedValue: planet.dWebServicesAPIKey ?? "")
        _juiceboxEnabled = State(wrappedValue: planet.juiceboxEnabled ?? false)
        _juiceboxProjectID = State(wrappedValue: planet.juiceboxProjectID?.stringValue() ?? "")
        _juiceboxProjectIDGoerli = State(
            wrappedValue: planet.juiceboxProjectIDGoerli?.stringValue() ?? ""
        )
        _pinnableEnabled = State(wrappedValue: planet.pinnableEnabled ?? false)
        _pinnableAPIEndpoint = State(wrappedValue: planet.pinnableAPIEndpoint ?? "")
        _pinnablePinCID = State(wrappedValue: planet.pinnablePinCID ?? nil)
        _filebaseEnabled = State(wrappedValue: planet.filebaseEnabled ?? false)
        _filebasePinName = State(wrappedValue: planet.filebasePinName ?? "")
        _filebaseAPIToken = State(wrappedValue: planet.filebaseAPIToken ?? "")
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

        if let enabled = planet.pinnableEnabled, enabled {
            HStack {
                HStack {
                    Text("Pin Status")
                    Spacer()
                }
                .frame(width: CONTROL_CAPTION_WIDTH + 20)

                if let status = pinnablePinStatus {
                    Button {

                    } label: {
                        if let cid = pinnablePinCID {
                            if cid == planet.lastPublishedCID {
                                Label("Pinned", systemImage: "checkmark.circle.fill")
                            } else {
                                Label("Pinning", systemImage: "ellipsis")
                            }
                        } else {
                            Label("Error", systemImage: "exclamationmark.triangle.fill")
                        }
                    }

                    Spacer()
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }.onAppear {
                Task {
                    if let status = await planet.checkPinnablePinStatus()
                    {
                        pinnablePinStatus = status
                        if let cid = status.last_known_cid {
                            pinnablePinCID = cid
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

                            TextField("", text: $domain)
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
                                Text("About")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextEditor(text: $about)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .lineSpacing(8)
                                .disableAutocorrection(true)
                                .cornerRadius(6)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                )
                        }

                        HStack {
                            HStack {
                                Text("Author Name")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextField("", text: $authorName)
                                .textFieldStyle(.roundedBorder)
                        }

                        if !Self.isCroptop {
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
                    }
                    .padding(16)
                    .tabItem {
                        Text("Basic Info")
                    }
                    .tag("basic")

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

                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                            HStack {
                                Spacer()
                                Text("Mastodon:")
                            }
                            .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                            TextField("", text: $mastodonUsername)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                            HStack {
                                Spacer()
                                Text("Twitter:")
                            }
                            .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                            TextField("", text: $twitterUsername)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                            HStack {
                                Spacer()
                                Text("GitHub:")
                            }
                            .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                            TextField("", text: $githubUsername)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: PlanetUI.CONTROL_ITEM_GAP) {
                            HStack {
                                Spacer()
                                Text("Telegram:")
                            }
                            .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                            TextField("", text: $telegramUsername)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Social")
                    }
                    .tag("social")

                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        pinnableView()

                        Divider()
                        .padding(.top, 6)
                        .padding(.bottom, 6)

                        filebaseView()
                    }
                    .padding(16)
                    .tabItem {
                        Text("Pinning")
                    }
                    .tag("pinning")

                    VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 20 + 10)
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
                                Text("Project ID")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 20)

                            TextField("", text: $juiceboxProjectID)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            HStack {
                                Text("Project ID (Goerli)")
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 20)

                            TextField("", text: $juiceboxProjectIDGoerli)
                                .textFieldStyle(.roundedBorder)
                        }

                        Divider()
                            .padding(.top, 6)
                            .padding(.bottom, 6)

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
                        planet.plausibleEnabled = plausibleEnabled
                        planet.plausibleDomain = plausibleDomain.trim()
                        planet.plausibleAPIKey = plausibleAPIKey
                        planet.plausibleAPIServer = plausibleAPIServer
                        planet.twitterUsername = twitterUsername.sanitized().trim()
                        planet.githubUsername = githubUsername.sanitized().trim()
                        planet.telegramUsername = telegramUsername.sanitized().trim()
                        planet.mastodonUsername = mastodonUsername.sanitized().trim()
                        planet.dWebServicesEnabled = dWebServicesEnabled
                        planet.dWebServicesDomain = dWebServicesDomain
                        planet.dWebServicesAPIKey = dWebServicesAPIKey
                        planet.juiceboxEnabled = juiceboxEnabled
                        planet.juiceboxProjectID = Int(juiceboxProjectID)
                        planet.juiceboxProjectIDGoerli = Int(juiceboxProjectIDGoerli)
                        planet.pinnableEnabled = pinnableEnabled
                        planet.pinnableAPIEndpoint = pinnableAPIEndpoint
                        planet.filebaseEnabled = filebaseEnabled
                        planet.filebasePinName = filebasePinName
                        planet.filebaseAPIToken = filebaseAPIToken
                        Task {
                            try planet.save()
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
    }
}

extension MyPlanetEditView {
    func verifyUserInput() -> Int {
        var errors: Int = 0
        // TODO: Better sanity check goes here
        return errors
    }
}
