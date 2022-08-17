//
//  HelpLinkButton.swift
//  Planet
//
//  Created by Kai on 8/18/22.
//

import SwiftUI


struct HelpLinkButton: NSViewRepresentable {
    var helpLink: URL

    class Coordinator: NSObject {
        var parent: HelpLinkButton

        init(_ parent: HelpLinkButton) {
            self.parent = parent
        }

        @objc func onClickAction(_ sender: Any?) {
            guard let _ = sender as? NSButton else { return }
            NSWorkspace.shared.open(parent.helpLink)
        }
    }

    func makeNSView(context: Context) -> some NSView {
        let button = NSButton()
        button.title = ""
        button.bezelStyle = .helpButton
        button.target = context.coordinator
        button.action = #selector(context.coordinator.onClickAction(_:))
        return button
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}


struct HelpLinkButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            Text("Hello, Planet!")
            Spacer()
            HelpLinkButton(helpLink: URL(string: "https://planetable.xyz")!)
        }
        .padding()
        .frame(width: 200, height: 44)
    }
}
