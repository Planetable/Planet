//
//  CapsuleBar.swift
//  Planet
//
//  Created by Xin Liu on 12/8/23.
//

import SwiftUI

struct CapsuleBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("BorderColor"), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
