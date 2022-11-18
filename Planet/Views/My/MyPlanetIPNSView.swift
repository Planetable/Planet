//
//  MyPlanetIPNSView.swift
//  Planet
//
//  Created by Xin Liu on 11/3/22.
//

import SwiftUI

struct MyPlanetIPNSView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: PlanetUI.CONTROL_ROW_SPACING) {
                HStack(spacing: 10) {
                    planet.smallAvatarAndNameView()
                    Spacer()
                }

                GroupBox {
                    VStack(spacing: 10) {
                        if planet.ipns.count > 0, planet.ipns.hasPrefix("k") {
                            HStack {
                                HStack {
                                    Text("IPNS")
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                }.frame(width: 40)
                                Text("\(planet.ipns)")
                                    .font(.system(size: 11, design: .monospaced))
                                Spacer()
                                Button {
                                    if let url = IPFSDaemon.urlForIPNS(planet.ipns) {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    Image(systemName: "globe")
                                }.help("Open IPNS in Public Gateway")

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(planet.ipns, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }.help("Copy IPNS to clipboard")

                            }
                        }
                        if let cid: String = planet.lastPublishedCID {
                            Divider()

                            HStack {
                                HStack {
                                    Text("CID")
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                }.frame(width: 40)
                                Text("\(cid)")
                                    .font(.system(size: 11, design: .monospaced))
                                Spacer()
                                Button {
                                    if let url = IPFSDaemon.urlForCID(cid) {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    Image(systemName: "globe")
                                }.help("Open CID in Public Gateway")

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(cid, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }.help("Copy CID to clipboard")

                            }
                        }
                        else {
                            Spacer()
                        }
                    }.padding(8)
                }

                HStack(spacing: 8) {
                    HelpLinkButton(helpLink: URL(string: "https://planetable.xyz/guides/")!)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("OK")
                            .frame(width: 50)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }

            }.padding(PlanetUI.SHEET_PADDING)
        }
        .padding(0)
        .frame(width: 620, height: 188, alignment: .top)
    }
}
