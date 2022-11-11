//
//  AccountBadgeView.swift
//  Planet
//
//  Created by Xin Liu on 11/10/22.
//

import SwiftUI
import Web3

struct AccountBadgeView: View {
    var walletAddress: String
    @State private var avatarImage: NSImage?
    @State private var displayName: String = ""
    @State private var displayBalance: String = ""

    var body: some View {
        HStack(spacing: 8) {
            if let avatarImage = avatarImage {
                HStack(spacing: 0) {
                    Image(nsImage: avatarImage)
                        .interpolation(Image.Interpolation.high)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36, alignment: .center)
                        .cornerRadius(36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 36)
                                .stroke(Color("BorderColor"), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                }.padding(2)
            } else {
                Text(" ")
                    .font(Font.custom("Arial Rounded MT Bold", size: 18))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: 36, height: 36, alignment: .center)
                    .background(
                        LinearGradient(
                            gradient: ViewUtils.getPresetGradient(from: walletAddress),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(Color("BorderColor"), lineWidth: 1)
                    )
                    .padding(2)
                    
            }

            VStack(spacing: 2) {
                HStack {
                    Text(displayName)
                        .font(.system(.body, design: .rounded))
                    Spacer()
                }
                HStack {
                    Text(displayBalance)
                        .font(.system(.footnote))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

        }
        .background(Color("AccountBadgeBackgroundColor"))
        .cornerRadius(40)
        .frame(idealWidth: 200, maxWidth: 300, idealHeight: 40, maxHeight: 40)
        .padding(10)
        .onAppear {
            DispatchQueue.main.async {
                self.displayName = walletAddress.shortWalletAddress()
            }
            // Get ENS and avatar image
            let ensURL = URL(string: "https://api.ensideas.com/ens/resolve/\(walletAddress)")!
            URLSession.shared.dataTask(with: ensURL) { data, response, error in
                if let data = data {
                    let json = try? JSONSerialization.jsonObject(with: data, options: [])
                    if let dictionary = json as? [String: Any] {
                        if let displayName = dictionary["displayName"] as? String {
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
        .onTapGesture {
            PlanetStore.shared.isShowingWalletAccount = true
        }
    }
}

struct AccountBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        AccountBadgeView(walletAddress: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
    }
}
