//
//  OnboardingView.swift
//  Planet
//
//  Created by Xin Liu on 6/24/22.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                VStack(spacing: 20) {
                    Text("Welcome to Planet")
                        .font(.largeTitle)
                    Text(
                        """
                        Planet lets you build and host your website on your Mac without requiring a centralized service. \
                        You can also use Planet to follow the content creators you like. \
                        The big difference is that there is no middle layer between you and the content creators you follow. \
                        You will receive the latest updates in a peer-to-peer manner.
                        """)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        Image(systemName: "network")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48, alignment: .leading)
                            .foregroundColor(.accentColor)
                        Text("Build and publish and follow websites on IPFS")
                            .font(.system(size: 16))
                        Spacer()
                    }

                    HStack(spacing: 20) {
                        Image(systemName: "tray.2")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48, alignment: .leading)
                            .foregroundColor(.accentColor)
                        Text("Manage multiple IPNS ready to be linked to your ENS")
                            .font(.system(size: 16))
                        Spacer()
                    }
                    HStack(spacing: 20) {
                        Image(systemName: "rectangle.leadinghalf.filled")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48, alignment: .leading)
                            .foregroundColor(.accentColor)
                        Text("Two-column Markdown editor for writing and previewing")
                            .font(.system(size: 16))
                        Spacer()
                    }

                    HStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48, alignment: .leading)
                            .foregroundColor(.accentColor)
                        Text("Export and import websites between Macs")
                            .font(.system(size: 16))
                        Spacer()
                    }

                }
                .padding(.vertical, 20)
            }
            .padding(.horizontal, 40)
            HStack {
                Spacer()
                Link("Read the Latest Release Notes  ❯", destination: URL(string: "https://planetable.eth.limo/feature-update-14/")!)
                Spacer()
            }
            Divider()
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                }.keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.large)
            }
        }
        .padding(.vertical, 40)
        .background(Color(NSColor.textBackgroundColor))
        .frame(width: PlanetUI.SHEET_WIDTH_LARGE)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView()
        }
    }
}
