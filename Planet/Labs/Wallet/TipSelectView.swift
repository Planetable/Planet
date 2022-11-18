//
//  TipSelectView.swift
//  Planet
//
//  Created by Xin Liu on 11/15/22.
//

import SwiftUI

struct TipSelectView: View {
    @AppStorage(String.settingsEthereumTipAmount) private var tipAmount: Int = UserDefaults
        .standard.integer(forKey: String.settingsEthereumTipAmount)

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text("Support this creator vitalik.eth")
                    .font(.title2)
                Spacer()
            }.padding(10)

            Divider()
            HStack {
                Text("Please select the amount")
                Spacer()
            }.padding(10)

            GroupBox {
                VStack {
                    HStack(spacing: 20) {
                        Picker(selection: $tipAmount, label: Text("")) {
                                ForEach(TipAmount.allCases, id: \.id) { value in
                                    Text(
                                        "\(TipAmount.names[value.rawValue] ?? "\(value.rawValue) Ξ")"
                                    )
                                    .tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                    }
                }.padding(15)
            }
            .padding(10)
            .frame(width: 400, height: 80)

            Divider()

            HStack(spacing: 8) {
                HelpLinkButton(helpLink: URL(string: "https://planetable.xyz/guides/")!)

                Spacer()

                Button {

                } label: {
                    Text("Cancel")
                }

                Button {

                } label: {
                    Text("Send")
                }
            }.padding(10)
        }
        .padding(0)
        .frame(width: 400, height: 200, alignment: .center)
        .background(Color(.textBackgroundColor))
    }
}

struct TipSelectView_Previews: PreviewProvider {
    static var previews: some View {
        TipSelectView()
    }
}
