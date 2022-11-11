//
//  WalletAccountView.swift
//  Planet
//
//  Created by Xin Liu on 11/11/22.
//

import SwiftUI
import Web3

struct WalletAccountView: View {
    var walletAddress: String
    @State private var avatarImage: NSImage?
    @State private var ensName: String?
    @State private var displayName: String = " "
    @State private var displayBalance: String = " "
    
    let AVATAR_SIZE: CGFloat = 64

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                if let avatarImage = avatarImage {
                    Image(nsImage: avatarImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: AVATAR_SIZE, height: AVATAR_SIZE, alignment: .center)
                        .cornerRadius(AVATAR_SIZE)
                        .overlay(
                            RoundedRectangle(cornerRadius: AVATAR_SIZE)
                                .stroke(Color("BorderColor"), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                } else {
                    Text(" ")
                        .font(Font.custom("Arial Rounded MT Bold", size: 24))
                        .foregroundColor(Color.white)
                        .contentShape(Rectangle())
                        .frame(width: AVATAR_SIZE, height: AVATAR_SIZE, alignment: .center)
                        .background(
                            LinearGradient(
                                gradient: ViewUtils.getPresetGradient(from: walletAddress),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(AVATAR_SIZE)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: AVATAR_SIZE)
                                .stroke(Color("BorderColor"), lineWidth: 1)
                        )
                }
                VStack {
                    HStack {
                        Text(displayName)
                            .font(.largeTitle)
                            .lineLimit(1)
                        Spacer()
                    }
                    HStack {
                        Text(walletAddress)
                            .font(.body)
                            .foregroundColor(Color(.secondaryLabelColor))
                            .lineLimit(1)
                        Spacer()
                    }
                    HStack {
                        Text(displayBalance)
                            .font(.body)
                            .foregroundColor(Color(.secondaryLabelColor))
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }.padding(10)

            Divider()

            Spacer()

            Divider()

            HStack(spacing: 8) {
                Button {
                    guard let session = WalletManager.shared.walletConnect.session else {
                        dismiss()
                        return
                    }
                    try? WalletManager.shared.walletConnect.client.disconnect(from: session)
                    dismiss()
                } label: {
                    Text("Disconnect")
                }
                
                Spacer()

                Button {
                    let etherscanURL = URL(string: "https://etherscan.io/address/\(walletAddress)")!
                    NSWorkspace.shared.open(etherscanURL)
                } label: {
                    Text("Etherscan")
                }

                Button {
                    let rainbowProfileURL: String
                    if let ensName = self.ensName {
                        rainbowProfileURL = "https://rainbow.me/\(ensName)"
                    } else {
                        rainbowProfileURL = "https://rainbow.me/\(walletAddress)"
                    }
                    NSWorkspace.shared.open(URL(string: rainbowProfileURL)!)
                } label: {
                    Text("Rainbow.me")
                }

                Button {
                    dismiss()
                } label: {
                    Text("OK")
                        .frame(minWidth: 50)
                }
                .keyboardShortcut(.escape, modifiers: [])
            }.padding(10)
        }
        .padding(0)
        .frame(width: 480, height: 240, alignment: .top)
        .onAppear {
            self.displayName = walletAddress.shortWalletAddress()
            // Get ENS and avatar image
            let ensURL = URL(string: "https://api.ensideas.com/ens/resolve/\(walletAddress)")!
            URLSession.shared.dataTask(with: ensURL) { data, response, error in
                if let data = data {
                    let json = try? JSONSerialization.jsonObject(with: data, options: [])
                    if let dictionary = json as? [String: Any] {
                        if let displayName = dictionary["displayName"] as? String {
                            if displayName.contains(".") {
                                DispatchQueue.main.async {
                                    self.ensName = displayName
                                }
                            }
                            DispatchQueue.main.async {
                                self.displayName = displayName
                            }
                        }
                        if let avatarURL = dictionary["avatar"] as? String {
                            let url = URL(string: avatarURL)!
                            let data = try? Data(contentsOf: url)
                            if let data = data {
                                let image = NSImage(data: data)
                                DispatchQueue.main.async {
                                    avatarImage = image
                                }
                            }
                        }
                    }
                }
            }.resume()
            // Get balance with Web3.swift
            let web3 = Web3(rpcURL: "https://cloudflare-eth.com")
            web3.eth.blockNumber() { response in
                if response.status.isSuccess, let blockNumber = response.result {
                    print("Block number: \(blockNumber)")
                    if let address = try? EthereumAddress(hex: walletAddress, eip55: false) {
                        web3.eth.getBalance(address: address, block: .block(blockNumber.quantity)) { response in
                            if response.status.isSuccess, let balance = response.result {
                                print("Balance: \(balance)")
                                // Format the balance
                                let ethers = Double(balance.quantity) / Double(1000000000000000000)
                                debugPrint("ethers: \(ethers)")
                                DispatchQueue.main.async {
                                    displayBalance = String(format: "%.2f ETH", ethers)
                                }
                            } else {
                                print("Error: \(response.error!)")
                            }
                        }
                    }
                }
            }
        }
    }
}

struct WalletAccountView_Previews: PreviewProvider {
    static var previews: some View {
        WalletAccountView(walletAddress: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
    }
}
