//
//  WalletTransactionProgressView.swift
//  Planet
//
//  Created by Xin Liu on 11/17/22.
//

import SwiftUI

struct WalletTransactionProgressView: View {
    var message: String
    
    var body: some View {
        VStack(spacing: 10) {
            if let attributedString = try? AttributedString(
                markdown: message
            ) {
                Text(attributedString)
                    .font(.body)
            }
            else {
                Text(message)
                    .font(.body)
            }
            ProgressView()
                .progressViewStyle(.linear)
        }
        .frame(width: PlanetUI.SHEET_WIDTH_PROGRESS_VIEW)
        .padding(PlanetUI.SHEET_PADDING)
    }
}

struct WalletTransactionProgressView_Previews: PreviewProvider {
    static var previews: some View {
        WalletTransactionProgressView(message: "Sending 0.01 Ξ to **vitalik.eth** on mainnet")
    }
}
