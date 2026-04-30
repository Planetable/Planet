//
//  PlanetSettingsLayout.swift
//  Planet
//

import SwiftUI

enum PlanetSettingsSharedLayout {
    static let labelWidth: CGFloat = PlanetUI.SETTINGS_CAPTION_WIDTH + 8
    static let containerMaxWidth: CGFloat = 840
    static let columnSpacing: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let descriptionSpacing: CGFloat = 6
    static let buttonSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 0
    static let verticalPadding: CGFloat = 0
}

struct PlanetSettingsContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: PlanetSettingsSharedLayout.sectionSpacing) {
                content
            }
            .frame(maxWidth: PlanetSettingsSharedLayout.containerMaxWidth, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PlanetSettingsSharedLayout.horizontalPadding)
        .padding(.vertical, PlanetSettingsSharedLayout.verticalPadding)
    }
}

struct PlanetSettingsRow<Content: View>: View {
    private let title: String
    private let alignment: VerticalAlignment
    private let content: Content

    init(
        _ title: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: PlanetSettingsSharedLayout.columnSpacing) {
            Text(L10n(title))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: PlanetSettingsSharedLayout.labelWidth, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlanetSettingsControlRow<Content: View>: View {
    private let alignment: VerticalAlignment
    private let content: Content

    init(
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: PlanetSettingsSharedLayout.columnSpacing) {
            Color.clear
                .frame(width: PlanetSettingsSharedLayout.labelWidth, height: 1)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlanetSettingsDescriptionRow: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        PlanetSettingsControlRow(alignment: .top) {
            Text(L10n(text))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
