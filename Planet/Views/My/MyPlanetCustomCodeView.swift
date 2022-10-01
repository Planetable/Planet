//
//  MyPlanetCustomCodeView.swift
//  Planet
//
//  Created by Xin Liu on 9/30/22.
//

import CodeMirror_SwiftUI
import SwiftUI

struct MyPlanetCustomCodeView: View {
    let CONTROL_ROW_SPACING: CGFloat = 8

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State private var name: String

    @State private var codeMode = CodeMode.html.mode()
    @State private var selectedTheme = 0
    @State private var fontSize = 14
    @State private var showInvisibleCharacters = false
    @State private var lineWrapping = true

    private var themes = CodeViewTheme.allCases.sorted {
        return $0.rawValue < $1.rawValue
    }

    @State private var customCodeHeadEnabled: Bool = false
    @State private var customCodeHead: String

    @State private var customCodeBodyStartEnabled: Bool = false
    @State private var customCodeBodyStart: String

    @State private var customCodeBodyEndEnabled: Bool = false
    @State private var customCodeBodyEnd: String

    init(planet: MyPlanetModel) {
        self.planet = planet
        _name = State(wrappedValue: planet.name)

        _customCodeHeadEnabled = State(wrappedValue: planet.customCodeHeadEnabled ?? false)
        _customCodeHead = State(wrappedValue: planet.customCodeHead ?? "")

        _customCodeBodyStartEnabled = State(
            wrappedValue: planet.customCodeBodyStartEnabled ?? false
        )
        _customCodeBodyStart = State(wrappedValue: planet.customCodeBodyStart ?? "")

        _customCodeBodyEndEnabled = State(wrappedValue: planet.customCodeBodyEndEnabled ?? false)
        _customCodeBodyEnd = State(wrappedValue: planet.customCodeBodyEnd ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {

                HStack(spacing: 10) {

                    if let image = planet.avatar {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24, alignment: .center)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("BorderColor"), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    else {
                        Text(planet.nameInitials)
                            .font(Font.custom("Arial Rounded MT Bold", size: 12))
                            .foregroundColor(Color.white)
                            .contentShape(Rectangle())
                            .frame(width: 24, height: 24, alignment: .center)
                            .background(
                                LinearGradient(
                                    gradient: ViewUtils.getPresetGradient(from: planet.id),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("BorderColor"), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }

                    Text("\(planet.name)")
                        .font(.body)

                    Spacer()
                }

                TabView {
                    VStack(spacing: CONTROL_ROW_SPACING) {
                        HStack {
                            Toggle(
                                "Enable custom code inside <head></head>",
                                isOn: $customCodeHeadEnabled
                            )
                            .toggleStyle(.checkbox)
                            .frame(alignment: .leading)
                            Spacer()
                        }

                        HStack {
                            GeometryReader { reader in
                                ScrollView {
                                    CodeView(
                                        theme: CodeViewTheme(rawValue: "friendship-bracelet")
                                            ?? themes[selectedTheme],
                                        code: $customCodeHead,
                                        mode: codeMode,
                                        fontSize: fontSize,
                                        showInvisibleCharacters: showInvisibleCharacters,
                                        lineWrapping: lineWrapping
                                    )
                                    .frame(height: reader.size.height)
                                    .tag(2)
                                }.frame(height: reader.size.height)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Head")
                    }

                    VStack(spacing: CONTROL_ROW_SPACING) {
                        HStack {
                            Toggle(
                                "Enable custom code after the start of <body>",
                                isOn: $customCodeBodyStartEnabled
                            )
                            .toggleStyle(.checkbox)
                            .frame(alignment: .leading)
                            Spacer()
                        }

                        HStack {
                            GeometryReader { reader in
                                ScrollView {
                                    CodeView(
                                        theme: CodeViewTheme(rawValue: "friendship-bracelet")
                                            ?? themes[selectedTheme],
                                        code: $customCodeBodyStart,
                                        mode: codeMode,
                                        fontSize: fontSize,
                                        showInvisibleCharacters: showInvisibleCharacters,
                                        lineWrapping: lineWrapping
                                    )
                                    .onLoadSuccess {
                                        print("Loaded")
                                    }
                                    .onContentChange { newCode in
                                        print("Content Change")
                                    }
                                    .onLoadFail { error in
                                        print("Load failed : \(error.localizedDescription)")
                                    }
                                    .frame(height: reader.size.height)
                                    .tag(2)
                                }.frame(height: reader.size.height)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Body Start")
                    }

                    VStack(spacing: CONTROL_ROW_SPACING) {
                        HStack {
                            Toggle(
                                "Enable custom code before </body>",
                                isOn: $customCodeBodyEndEnabled
                            )
                            .toggleStyle(.checkbox)
                            .frame(alignment: .leading)
                            Spacer()
                        }

                        HStack {
                            GeometryReader { reader in
                                ScrollView {
                                    CodeView(
                                        theme: CodeViewTheme(rawValue: "friendship-bracelet")
                                            ?? themes[selectedTheme],
                                        code: $customCodeBodyEnd,
                                        mode: codeMode,
                                        fontSize: fontSize,
                                        showInvisibleCharacters: showInvisibleCharacters,
                                        lineWrapping: lineWrapping
                                    )
                                    .frame(height: reader.size.height)
                                    .tag(2)
                                }.frame(height: reader.size.height)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .tabItem {
                        Text("Body End")
                    }
                }

                HStack(spacing: 8) {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(width: 50)
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button {
                        planet.customCodeHeadEnabled = customCodeHeadEnabled
                        planet.customCodeHead = customCodeHead
                        planet.customCodeBodyStartEnabled = customCodeBodyStartEnabled
                        planet.customCodeBodyStart = customCodeBodyStart
                        planet.customCodeBodyEndEnabled = customCodeBodyEndEnabled
                        planet.customCodeBodyEnd = customCodeBodyEnd
                        Task {
                            try planet.save()
                            try planet.copyTemplateAssets()
                            try planet.articles.forEach { try $0.savePublic() }
                            try planet.savePublic()
                            NotificationCenter.default.post(name: .loadArticle, object: nil)
                            try await planet.publish()
                        }
                        dismiss()
                    } label: {
                        Text("OK")
                            .frame(width: 50)
                    }
                    .disabled(name.isEmpty)
                }

            }.padding(20)
        }
        .padding(0)
        .frame(width: 520, height: 460, alignment: .top)
        .task {
            name = planet.name
        }
    }
}
