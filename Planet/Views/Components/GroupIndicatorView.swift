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
                Image("multi")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16)
                    .padding(1)
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
