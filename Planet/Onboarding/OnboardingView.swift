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
                    Text("Planet lets you build and host your website on your Mac without requiring a centralized service. You can also use Planet to follow the content creators you like. The big difference is that there is no middle layer between you and the content creators you follow. You will receive the latest updates in a peer-to-peer manner.")
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        Image(systemName: "network")
                            .resizable()
                            .frame(width: 48, height: 48, alignment: .leading)
                        Text("Build and publish and follow websites on IPFS")
                            .font(.system(size: 16))
                        Spacer()
                    }
                    
                    HStack(spacing: 20) {
                        Image(systemName: "tray.2")
                            .resizable()
                            .frame(width: 48, height: 48, alignment: .leading)
                        Text("Manage multiple IPNS ready to be linked to your ENS")
                            .font(.system(size: 16))
                        Spacer()
                    }
                    
                    HStack(spacing: 20) {
                        Image(systemName: "rectangle.leadinghalf.filled")
                            .resizable()
                            .frame(width: 48, height: 48, alignment: .leading)
                        Text("Two-column Markdown editor for writing and previewing")
                            .font(.system(size: 16))
                        Spacer()
                    }
                    
                    HStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .resizable()
                            .frame(width: 48, height: 48, alignment: .leading)
                        Text("Export and import websites between Macs")
                            .font(.system(size: 16))
                        Spacer()
                    }
                    
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
            }
            .padding(.leading, 40)
            .padding(.trailing, 40)
            Divider()
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 40)
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView()
        }
    }
}
