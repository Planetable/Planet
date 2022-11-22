//
//  IndicatorLabelView.swift
//  Planet
//
//  Created by Kai on 11/22/22.
//

import SwiftUI


struct IndicatorLabelView: View {
    var dotColor: Color
    var foregroundColor: Color
    var backgroundColor: Color
    var title: String
    var subtitle: String

    init(dotColor: Color = .accentColor, foregroundColor: Color = .primary, backgroundColor: Color = Color(nsColor: .controlBackgroundColor), title: String, subtitle: String?) {
        self.dotColor = dotColor
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.title = title
        self.subtitle = subtitle ?? ""
    }

    var body: some View {
        GeometryReader { g in
            let padding: CGFloat = g.size.height / 4.0
            let radius: CGFloat = g.size.height / 4.5
            HStack (spacing: padding) {
                Spacer(minLength: 0)
                VStack (spacing: 0) {
                    dotView(radius: radius)
                }
                VStack (spacing: 0) {
                    Spacer(minLength: 0)
                    if subtitle != "" {
                        HStack (spacing: 0) {
                            Text(title)
                                .lineLimit(1)
                                .font(.headline)
                            Spacer(minLength: 0)
                        }
                        HStack (spacing: 0) {
                            Text(subtitle)
                                .lineLimit(1)
                                .font(.subheadline)
                                .foregroundColor(foregroundColor.opacity(0.5))
                            Spacer(minLength: 0)
                        }
                    } else {
                        HStack (spacing: 0) {
                            Text(title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundColor(foregroundColor)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, padding)
            .background(RoundedRectangle(cornerRadius: g.size.height / 2.0).fill(backgroundColor))
            .shadow(color: .black.opacity(0.035), radius: padding, x: 0, y: 1)
        }
    }

    @ViewBuilder
    private func dotView(radius: CGFloat) -> some View {
        let size: CGSize = CGSize(width: radius, height: radius)
        Circle()
            .frame(width: size.width, height: size.height)
            .foregroundColor(dotColor)
            .cornerRadius(size.width / 2.0)
    }
}

struct IndicatorLabelView_Previews: PreviewProvider {
    static var previews: some View {
        VStack (spacing: 20) {
            IndicatorLabelView(title: "Title", subtitle: nil)
                .frame(maxWidth: 120, maxHeight: 44)

            IndicatorLabelView(title: "Hello", subtitle: nil)
                .frame(width: 90, height: 32)

            IndicatorLabelView(title: "Welcome", subtitle: nil)
                .frame(width: 122, height: 44)

            IndicatorLabelView(title: "Welcome", subtitle: "Description Here")
                .frame(width: 160, height: 44)
        }
        .frame(width: 200, height: 400)
    }
}
