//
//  TipSelectView.swift
//  Planet
//
//  Created by Xin Liu on 11/15/22.
//

import Combine
import SwiftUI
import Web3

struct TipSelectView: View {
    @Environment(\.dismiss) var dismiss
    /*
    @AppStorage(String.settingsEthereumChainId) private var ethereumChainId: Int = UserDefaults
        .standard.integer(forKey: String.settingsEthereumChainId)
    */
    #if DEBUG
    @State private var ethereumChainId: Int = EthereumChainID.sepolia.rawValue
    #else
    @State private var ethereumChainId: Int = EthereumChainID.mainnet.rawValue
    #endif
    @AppStorage(String.settingsEthereumTipAmount) private var tipAmount: Int = UserDefaults
        .standard.integer(forKey: String.settingsEthereumTipAmount)

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var currentGasPrice: Int? = nil

    var receiver: String
    var ens: String?
    var memo: String

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                if let title = titleString() {
                    Text(title)
                    .font(.title2)
                } else {
                    Text(titleStringPlain())
                    .font(.title2)
                }
                Spacer()
                if let gasPrice = currentGasPrice {
                    Label(String(gasPrice), systemImage: "fuelpump.fill")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }.padding(10)

            Divider()
            HStack {
                Text("Please select the amount")

                Spacer()

                Text("\(EthereumChainID.names[ethereumChainId] ?? "Unknown Chain ID \(ethereumChainId)")")

                // TODO: If we want to allow users to switch network, we need to add this back, and pass the chain ID to the send function
                /*
                Picker(selection: $ethereumChainId, label: Text("")) {
                    ForEach(EthereumChainID.allCases, id: \.id) { value in
                        Text(
                            "\(EthereumChainID.names[value.rawValue] ?? "Unknown Chain ID \(value.rawValue)")"
                        )
                        .tag(value)
                        .frame(width: 120)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                */

                /* TODO: Remove this V1 logic
                if WalletManager.shared.canSwitchNetwork() {
                    Picker(selection: $ethereumChainId, label: Text("")) {
                        ForEach(EthereumChainID.allCases, id: \.id) { value in
                            Text(
                                "\(EthereumChainID.names[value.rawValue] ?? "Unknown Chain ID \(value.rawValue)")"
                            )
                            .tag(value)
                            .frame(width: 120)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                } else {
                    if let connectedWalletChainId = WalletManager.shared.connectedWalletChainId(), let name = EthereumChainID.names[connectedWalletChainId] {
                        Text(
                            "\(name)"
                        )
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .trailing)
                        .help("This transaction will be sent to \(name) network")
                    }
                }
                */
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
                HelpLinkButton(helpLink: URL(string: "https://www.planetable.xyz/guides/walletconnect/")!)

                Button {
                    if let etherscanURL = URL(string: WalletManager.shared.etherscanURLString(address: receiver)) {
                        NSWorkspace.shared.open(etherscanURL)
                    }
                } label: {
                    Text("Etherscan")
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(width: 50)
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    send()
                } label: {
                    Text("Send")
                        .frame(width: 50)
                }.buttonStyle(.borderedProminent)
            }.padding(10)
        }
        .padding(0)
        .frame(width: 400, height: 200, alignment: .center)
        .background(Color(.textBackgroundColor))
        .onReceive(timer) { time in
            debugPrint("[\(time)] Updating current gas price...")
            updateCurrentGasPrice()
        }
    }

    private func updateCurrentGasPrice() {
        let chain = EthereumChainID(rawValue: ethereumChainId) ?? .mainnet
        let web3 = Web3(rpcURL: chain.rpcURL)
        web3.eth.gasPrice() { response in
            if response.status.isSuccess, let gasPrice = response.result {
                print("Gas price: \(gasPrice)")
                // Format the gas price
                let gweis: Int = Int(Double(gasPrice.quantity) / Double(1_000_000_000))
                debugPrint("gweis: \(gweis)")
                DispatchQueue.main.async {
                    currentGasPrice = gweis
                }
            } else {
                print("Error: \(response.error!)")
            }
        }
    }

    private func send() {
        guard let tipAmountLabel = TipAmount.names[tipAmount] else {
            debugPrint("Tipping: unable to find a matching label for tip amount: \(tipAmount)")
            return
        }
        let ethereumChainName = WalletManager.shared.currentNetworkName()
        var walletAppString: String = ""
        let walletAppName = WalletManager.shared.getWalletAppName()
        walletAppString = walletAppName + " on"
        let message: String
        if let ens = ens {
            message = "Sending \(tipAmountLabel) to **\(ens)** on \(ethereumChainName), please confirm from \(walletAppString) your phone"
        } else {
            message = "Sending \(tipAmountLabel) to **\(receiver)** on \(ethereumChainName), please confirm from \(walletAppString) your phone"
        }
        dismiss()
        Task { @MainActor in
            PlanetStore.shared.walletTransactionProgressMessage = message
            PlanetStore.shared.isShowingWalletTransactionProgress = true
        }
        // WalletManager.shared.walletConnect.sendTransaction(receiver: receiver, amount: tipAmount, memo: memo, ens: ens)
        Task {
            await WalletManager.shared.sendTransactionV2(receiver: receiver, amount: tipAmount, memo: memo, ens: ens, gas: currentGasPrice)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            PlanetStore.shared.isShowingWalletTransactionProgress = false
        }
    }

    private func titleString() -> AttributedString? {
        var title: String
        let etherscanURLString: String = WalletManager.shared.etherscanURLString(address: receiver)
        if let ens = ens {
            title = "Support this creator [`\(ens)`](\(etherscanURLString))"
        } else {
            title = "Support this creator [`" + receiver.shortWalletAddress() + "`](\(etherscanURLString))"
        }
        if let attributedString = try? AttributedString(markdown: title) {
            return attributedString
        } else {
            return nil
        }
    }

    private func titleStringPlain() -> String {
        var title: String
        if let ens = ens {
            title = "Support this creator \(ens)"
        } else {
            title = "Support this creator " + receiver.shortWalletAddress()
        }
        return title
    }
}

struct TipSelectView_Previews: PreviewProvider {
    static var previews: some View {
        TipSelectView(receiver: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", ens: "vitalik.eth", memo: "planet:vitalik.eth")
    }
}
