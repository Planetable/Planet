import SwiftUI

struct EditMyPlanetView: View {
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: MyPlanetModel
    @State private var name = ""
    @State private var about = ""
    @State private var templateName = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Planet")
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)

            Divider()

            VStack(spacing: 15) {
                HStack(alignment: .top) {
                    HStack {
                        Text("Name")
                        Spacer()
                    }
                    .frame(width: 70)

                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 16)

                HStack(alignment: .top) {
                    HStack {
                        Text("About")
                        Spacer()
                    }
                    .frame(width: 70)

                    TextEditor(text: $about)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .lineSpacing(8)
                        .disableAutocorrection(true)
                        .cornerRadius(6)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1.0)
                        )
                }

                Picker(selection: $templateName) {
                    ForEach(TemplateStore.shared.templates) { template in
                        Text(template.name)
                            .tag(template.name)
                    }
                } label: {
                    HStack {
                        Text("Template")
                        Spacer()
                    }
                    .frame(width: 70)
                }
                .pickerStyle(.menu)

                Spacer()
            }
            .padding(.horizontal, 16)

            Divider()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    if !name.isEmpty {
                        planet.name = name
                    }
                    planet.about = about
                    planet.templateName = templateName
                    do {
                        try planet.save()
                        try planet.copyTemplateAssets()
                        try planet.savePublic()
                    } catch {
                        // TODO: alert
                    }

                    Task {
                        do {
                            try await planet.publish()
                        } catch {}
                    }
                    // re-render all articles
                    NotificationCenter.default.post(name: .refreshArticle, object: nil)
                    dismiss()
                } label: {
                    Text("Save")
                }
                .disabled(name.isEmpty)
            }
            .padding(16)
        }
        .padding(0)
        .frame(width: 480, height: 300, alignment: .center)
        .task {
            name = planet.name
            about = planet.about
            templateName = planet.templateName
        }
    }
}
