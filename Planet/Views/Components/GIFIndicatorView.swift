//
//  GIFIndicatorView.swift
//  Planet
//
//  Created by Kai on 8/7/23.
//

import SwiftUI


struct GIFIndicatorView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text("GIF")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.75))
                    .cornerRadius(4)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.leading, 4)
            .padding(.bottom, 4)
        }
    }
}


struct VideoIndicatorView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text("MP4")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.75))
                    .cornerRadius(4)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.leading, 4)
            .padding(.bottom, 4)
        }
    }
}


struct PDFIndicatorView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text("PDF")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.75))
                    .cornerRadius(4)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.leading, 4)
            .padding(.bottom, 4)
        }
    }
}
