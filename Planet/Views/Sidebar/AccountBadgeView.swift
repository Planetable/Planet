//
//  AccountBadgeView.swift
//  Planet
//
//  Created by Xin Liu on 11/10/22.
//

import ENSKit
import SwiftUI
import SwiftyJSON
import Web3

struct AccountBadgeView: View {
    var walletAddress: String
    @State private var avatarImage: NSImage?
    @State private var displayName: String = ""
    @State private var displayBalance: String = ""
    @AppStorage(String.settingsEthereumChainId) private var currentActiveChainID = 1
    @State private var currentBackgroundColor = Color("AccountBadgeBackgroundColor")
    let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            if let avatarImage = avatarImage {
                HStack(spacing: 0) {
                    Image(nsImage: avatarImage)
                        .interpolation(.high)
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
            }
            else {
                Text(ViewUtils.getEmoji(from: walletAddress))
                    .font(Font.custom("Arial Rounded MT Bold", size: 24))
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
        .background(currentBackgroundColor)
        .cornerRadius(40)
        .frame(idealWidth: 200, maxWidth: 300, idealHeight: 40, maxHeight: 40)
        .padding(.top, 0)
        .padding(.bottom, 10)
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .contextMenu {
            Text(walletAddress)
                .font(.footnote)

            Text("Connected with \(WalletManager.shared.getWalletAppName())")
                .font(.footnote)

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(walletAddress, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                Text("Copy Address")
            }

            Divider()

            Button {
                if let url = URL(
                    string: WalletManager.shared.etherscanURLString(address: walletAddress)
                ) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "info.circle")
                Text("View on Etherscan")
            }

            Divider()

            Button {
                PlanetStore.shared.isShowingWalletDisconnectConfirmation = true
            } label: {
                Image(systemName: "eject")
                Text("Disconnect Wallet")
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                self.displayName = walletAddress.shortWalletAddress()
            }
            self.loadENS()
            self.loadBalance()
        }
        .onChange(of: currentActiveChainID) { _ in
            self.loadBalance()
        }
        .onHover { isHovering in
            withAnimation(Animation.easeInOut(duration: 0.25)) {
                self.currentBackgroundColor =
                    isHovering
                    ? Color("AccountBadgeBackgroundColorHover")
                    : Color("AccountBadgeBackgroundColor")
            }
        }
        .onTapGesture {
            PlanetStore.shared.isShowingWalletAccount = true
        }
        .onReceive(timer) { _ in
            self.loadBalance()
        }
    }

    private func loadENS() {
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
    }

    private func loadBalance() {
        // Verify NFT ownership for unlocking icons
        Task {
            do {
                try await verifyNFTOwnership(address: walletAddress)
            }
            catch {
                debugPrint("Error occurred when verifying NFT ownership: \(error)")
            }

        }
        // Get balance with Web3.swift
        let web3: Web3
        let currentActiveChain = EthereumChainID.allCases.first(where: {
            $0.id == currentActiveChainID
        })!
        switch currentActiveChain {
        case .mainnet:
            web3 = Web3(rpcURL: "https://cloudflare-eth.com")
        case .goerli:
            web3 = Web3(rpcURL: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161")
        case .sepolia:
            web3 = Web3(rpcURL: "https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161")
        }
        web3.eth.blockNumber { response in
            if response.status.isSuccess, let blockNumber = response.result {
                print("Block number: \(blockNumber)")
                if let address = try? EthereumAddress(hex: walletAddress, eip55: false) {
                    web3.eth.getBalance(address: address, block: .block(blockNumber.quantity)) {
                        response in
                        if response.status.isSuccess, let balance = response.result {
                            print("Balance: \(balance)")
                            // Format the balance
                            let ethers =
                                Double(balance.quantity) / Double(1_000_000_000_000_000_000)
                            debugPrint("ethers: \(ethers)")
                            DispatchQueue.main.async {
                                displayBalance = String(
                                    format:
                                        "%.2f \(EthereumChainID.coinNames[currentActiveChainID] ?? "ETH")",
                                    ethers
                                )
                            }
                        }
                        else {
                            print("Error: \(response.error!)")
                        }
                    }
                }
            }
        }
    }

    private func verifyNFTOwnership(address: String) async throws {
        let client = EthereumAPI.Cloudflare
        let addressInTopic =
            "0x000000000000000000000000" + address.dropFirst("0x".count).lowercased()
        let params: JSON = [
            [
                "address": "0x3f98e2b3237a61348585c9bdb30a5571ff59cc41",
                "topics": [
                    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                    "0x0000000000000000000000000000000000000000000000000000000000000000",
                    addressInTopic,
                ],
                "fromBlock": "earliest",
                "toBlock": "latest",
            ]
        ]
        let result = try await client.request(method: "eth_getLogs", params: params)
        switch result {
        case .error(_):
            debugPrint("Ethereum API error")
        case .result(let result):
            for item in result.arrayValue {
                let topic = item["topics"][3].stringValue
                let tokenID = String(topic.dropFirst("0x".count).drop(while: { $0 == "0" }))
                if let decimalID = UInt64(tokenID, radix: 16),
                    let tier = String(Int(decimalID)).first
                {
                    debugPrint("User has tier \(tier)")
                    do {
                        try IconManager.shared.unlockIcon(byIDString: String(tier))
                    } catch {
                        debugPrint("failed to unlock icon by id: \(tier), error: \(error)")
                    }
                }
            }
        }
    }
}

struct AccountBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        AccountBadgeView(walletAddress: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
    }
}
