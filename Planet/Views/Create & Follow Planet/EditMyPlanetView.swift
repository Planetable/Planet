import SwiftUI

struct EditMyPlanetView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 80
    let SOCIAL_CONTROL_CAPTION_WIDTH: CGFloat = 120

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State private var name: String
    @State private var about: String
    @State private var templateName: String

    @State private var plausibleEnabled: Bool = false
    @State private var plausibleDomain: String
    @State private var plausibleAPIKey: String
    @State private var plausibleAPIServer: String = "plausible.io"

    @State private var twitterUsername: String
    @State private var githubUsername: String

    init(planet: MyPlanetModel) {
        self.planet = planet
        _name = State(wrappedValue: planet.name)
        _about = State(wrappedValue: planet.about)
        _templateName = State(wrappedValue: planet.templateName)
        _plausibleEnabled = State(wrappedValue: planet.plausibleEnabled ?? false)
        _plausibleDomain = State(wrappedValue: planet.plausibleDomain ?? "")
        _plausibleAPIKey = State(wrappedValue: planet.plausibleAPIKey ?? "")
        _plausibleAPIServer = State(wrappedValue: planet.plausibleAPIServer ?? "plausible.io")
        _twitterUsername = State(wrappedValue: planet.twitterUsername ?? "")
        _githubUsername = State(wrappedValue: planet.githubUsername ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {

                HStack(spacing: 10) {

                    if let image = planet.avatar {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24, alignment: .center)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    } else {
                        Text(planet.nameInitials)
                            .font(Font.custom("Arial Rounded MT Bold", size: 12))
                            .foregroundColor(Color.white)
                            .contentShape(Rectangle())
                            .frame(width: 24, height: 24, alignment: .center)
                            .background(LinearGradient(
                                gradient: ViewUtils.getPresetGradient(from: planet.id),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                               .stroke(Color("BorderColor"), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }

                    Text("\(planet.name)")
                    .font(.body)

                    Spacer()
                }

            TabView {
                VStack(spacing: 15) {
                    HStack {
                        HStack {
                            Text("Name")
                            Spacer()
                        }
                        .frame(width: CONTROL_CAPTION_WIDTH)

                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
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
                .padding(16)
                .tabItem {
                    Text("Basic Info")
                }

                VStack(spacing: 15) {
                    HStack {
                        HStack {
                            Spacer()
                        }.frame(width: CONTROL_CAPTION_WIDTH + 10)
                        Toggle("Enable Plausible for Traffic Analytics", isOn: $plausibleEnabled)
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

                        TextField("", text: $plausibleAPIKey)
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

                VStack(spacing: 15) {
                    HStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Text("Twitter Username:")
                        }
                        .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                        TextField("", text: $twitterUsername)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Text("GitHub Username:")
                        }
                        .frame(width: SOCIAL_CONTROL_CAPTION_WIDTH)

                        TextField("", text: $githubUsername)
                            .textFieldStyle(.roundedBorder)
                    }

                }
                .padding(16)
                .tabItem {
                    Text("Social")
                }
            }

            HStack(spacing: 8) {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(width: 50)
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    if !name.isEmpty {
                        planet.name = name
                    }
                    planet.about = about
                    planet.templateName = templateName
                    planet.plausibleEnabled = plausibleEnabled
                    planet.plausibleDomain = plausibleDomain
                    planet.plausibleAPIKey = plausibleAPIKey
                    planet.plausibleAPIServer = plausibleAPIServer
                    planet.twitterUsername = twitterUsername
                    planet.githubUsername = githubUsername
                    Task {
                        try planet.save()
                        try planet.copyTemplateAssets()
                        try planet.articles.forEach { try $0.savePublic() }
                        try planet.savePublic()
                        NotificationCenter.default.post(name: .loadArticle, object: nil)
                        try await planet.publish()
                    }
                    dismiss()
                } label: {
                    Text("OK")
                        .frame(width: 50)
                }
                .disabled(name.isEmpty)
            }

            }.padding(20)
        }
        .padding(0)
        .frame(width: 520, height: 360, alignment: .top)
        .task {
            name = planet.name
            about = planet.about
            templateName = planet.templateName
        }
    }
}
