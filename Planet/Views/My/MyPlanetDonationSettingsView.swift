//
//  MyPlanetDonationSettingsView.swift
//  Planet
//
//  Created by Xin Liu on 8/30/24.
//

import SwiftUI

struct MyPlanetDonationSettingsView: View {
    let CONTROL_CAPTION_WIDTH: CGFloat = 120
    let CONTROL_ROW_SPACING: CGFloat = 8

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State private var name: String

    @State private var acceptsDonation: Bool = false
    @State private var acceptsDonationMessage: String = ""
    @State private var acceptsDonationETHAddress: String = ""

    init(planet: MyPlanetModel) {
        self.planet = planet
        _name = State(wrappedValue: planet.name)

        _acceptsDonation = State(wrappedValue: planet.acceptsDonation ?? false)
        _acceptsDonationMessage = State(wrappedValue: planet.acceptsDonationMessage ?? "")
        _acceptsDonationETHAddress = State(wrappedValue: planet.acceptsDonationETHAddress ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    planet.smallAvatarAndNameView()
                    Spacer()
                }

                TabView {
                    VStack(spacing: CONTROL_ROW_SPACING) {
                        HStack {
                            HStack {
                                Spacer()
                            }.frame(width: CONTROL_CAPTION_WIDTH + 10)
                            Toggle(
                                "Show Donate button",
                                isOn: $acceptsDonation
                            )
                            .toggleStyle(.checkbox)
                            .frame(alignment: .leading)
                            Spacer()
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 10)

                            Text(
                                "Show a Donate button on the site if the template you chose supports this setting. Your visitors can donate to you using ETH, and donations will be sent to the Ethereum address you set below."
                            )
                            .lineLimit(4)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack {
                            HStack {
                                Spacer()
                                Image("eth-logo")
                                    .interpolation(.high)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                                Text("ETH Address:")
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextEditor(text: $acceptsDonationETHAddress)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .padding(.all, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6).fill(
                                        Color(.textBackgroundColor)
                                    )
                                )
                                .lineSpacing(2)
                                .disableAutocorrection(true)
                                .cornerRadius(6)
                                .frame(height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                )
                        }

                        HStack {
                            HStack {
                                Spacer()
                                Text("Message:")
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH)

                            TextEditor(text: $acceptsDonationMessage)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .padding(.all, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6).fill(
                                        Color(.textBackgroundColor)
                                    )
                                )
                                .lineSpacing(2)
                                .disableAutocorrection(true)
                                .cornerRadius(6)
                                .frame(height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                )
                        }

                        HStack {
                            HStack {
                                Spacer()
                            }
                            .frame(width: CONTROL_CAPTION_WIDTH + 10)

                            Text(
                                "You can include a message to your visitors here. For example, you can thank them for their support, or let them know how the donations will be used. HTML can be used in this message."
                            )
                            .lineLimit(4)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                    }
                    .padding(16)
                    .tabItem {
                        Text("Donation Settings")
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
                        if verifyUserInput() > 0 {
                            return
                        }
                        planet.acceptsDonation = acceptsDonation
                        planet.acceptsDonationETHAddress = acceptsDonationETHAddress
                        planet.acceptsDonationMessage = acceptsDonationMessage
                        Task.detached(priority: .userInitiated) {
                            try await planet.save()
                            try await planet.copyTemplateAssets()
                            try await planet.articles.forEach { try $0.savePublic() }
                            try await planet.savePublic()
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

            }.padding(PlanetUI.SHEET_PADDING)
        }
        .padding(0)
        .frame(width: 520, height: 460, alignment: .top)
        .task {
            name = planet.name
        }
    }
}

extension MyPlanetDonationSettingsView {
    func verifyUserInput() -> Int {
        var errors: Int = 0
        // Verify ETH address
        let address = acceptsDonationETHAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isValidEthereumAddress {
            errors += 1

            let alert = NSAlert()
            alert.messageText = "Invalid ETH Address"
            alert.informativeText =
                "Please enter a valid Ethereum address. The address should start with '0x' and have exactly 42 characters."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        return errors
    }
}
