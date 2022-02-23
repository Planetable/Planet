//
//  PlanetWriterView.swift
//  Planet
//
//  Created by Kai on 2/22/22.
//

import SwiftUI


struct PlanetWriterView: View {
    var articleID: UUID
    
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        VStack (spacing: 0) {
            TextField("Title", text: $title)
                .frame(height: 34, alignment: .leading)
                .padding(.bottom, 2)
                .padding(.horizontal, 16)
                .font(.system(size: 15, weight: .regular, design: .default))
                .background(.clear)
                .textFieldStyle(PlainTextFieldStyle())

            Divider()
            
            TextEditor(text: $content)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .lineSpacing(10)
                .disableAutocorrection(true)

            Divider()
            
            HStack {
                Button {
                    closeAction()
                } label: {
                    Text("Cancel")
                }
                
                Spacer()
                
                Button {
                    saveAction()
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
    
    private func saveAction() {
        debugPrint("About to save ")
        // make sure current new article id equals to the planet id first, then generate new article id.
        let planetID = articleID
        let createdArticleID = UUID()
        PlanetDataController.shared.createArticle(withID: createdArticleID, forPlanet: planetID, title: title, content: content)
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

struct PlanetWriterView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetWriterView(articleID: .init())
    }
}
