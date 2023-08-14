//
//  GroupIndicatorView.swift
//  Planet
//
//  Created by Kai on 8/14/23.
//

import SwiftUI


struct GroupIndicatorView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "photo.on.rectangle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13)
                    .padding(3.5)
                    .foregroundColor(.white.opacity(0.85))
                    .background(Color.secondary.opacity(0.75))
                    .cornerRadius(4)
            }
            .padding(.trailing, 4)
            .padding(.top, 4)
            Spacer()
        }
    }
}
