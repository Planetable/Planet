//
//  PlanetWriterEditView.swift
//  Planet
//
//  Created by Kai on 4/1/22.
//

import SwiftUI


struct PlanetWriterEditView: View {
    var articleID: UUID

    @State var title: String = ""
    @State var content: String = ""

    var body: some View {
        VStack (spacing: 0) {
            HStack (spacing: 0) {
                TextField("Title", text: $title)
                    .frame(height: 34, alignment: .leading)
                    .padding(.bottom, 2)
                    .padding(.horizontal, 16)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .background(.clear)
                    .textFieldStyle(PlainTextFieldStyle())
                Spacer()
            }

            Divider()

            // MARK: TODO: Add Preview
            PlanetWriterTextView(text: $content, selectedRanges: .constant([]), writerID: articleID)

            Divider()

            HStack {
                Button {
                    closeAction()
                } label: {
                    Text("Cancel")
                }

                Spacer()

                Button {
                    updateAction()
                } label: {
                    Text("Save")
                }
                .disabled(title.count == 0)
            }
            .padding(16)
        }
        .padding(0)
        .frame(minWidth: 480, idealWidth: 480, maxWidth: .infinity, minHeight: 320, idealHeight: 320, maxHeight: .infinity, alignment: .center)
        .onReceive(NotificationCenter.default.publisher(for: .closeWriterWindow, object: nil)) { n in
            guard let id = n.object as? UUID else { return }
            guard id == self.articleID else { return }
            self.closeAction()
        }
    }

    private func closeAction() {
        DispatchQueue.main.async {
            if PlanetStore.shared.writerIDs.contains(articleID) {
                PlanetStore.shared.writerIDs.remove(articleID)
            }
            if PlanetStore.shared.activeWriterID == articleID {
                PlanetStore.shared.activeWriterID = .init()
            }
        }
    }

    private func updateAction() {
        PlanetDataController.shared.updateArticle(withID: articleID, title: title, content: content)
        DispatchQueue.main.async {
            if PlanetStore.shared.writerIDs.contains(articleID) {
                PlanetStore.shared.writerIDs.remove(articleID)
            }
            if PlanetStore.shared.activeWriterID == articleID {
                PlanetStore.shared.activeWriterID = .init()
            }
        }
    }
}
