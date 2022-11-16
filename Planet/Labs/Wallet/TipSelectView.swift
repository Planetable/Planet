//
//  TipSelectView.swift
//  Planet
//
//  Created by Xin Liu on 11/15/22.
//

import SwiftUI

struct TipSelectView: View {
    var body: some View {
        VStack {
            Divider()
            
            HStack {
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
            }
        }
    }
}

struct TipSelectView_Previews: PreviewProvider {
    static var previews: some View {
        TipSelectView()
    }
}
