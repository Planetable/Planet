//
//  TemplateBrowserSidebar.swift
//  Planet
//
//  Created by Livid on 4/13/22.
//

import SwiftUI

struct TemplateBrowserSidebar: View {
    @StateObject var store = TemplateBrowserStore.shared
    @Binding var selection: Template.ID?

    var body: some View {
        List(selection: $selection) {
            ForEach(store.templates, id: \.id) { template in
                HStack {
                    Text(template.name)
                    Spacer()
                    if template.hasGitRepo {
                        Text("GIT")
                            .font(.system(size: 8))
                    }
                }
                .contextMenu {
                    if hasVSCode() {
                        Button {
                            openVSCode(template)
                        } label: {
                            Text("Open in VSCode")
                        }
                    }

                    Button(action: {
                        revealInFinder(template)
                    }) {
                        Text("Reveal in Finder")
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }

    private func hasVSCode() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil
    }

    private func openVSCode(_ template: Template) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
        else { return }

        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: self.openConfiguration(), completionHandler: nil)
    }

    private func revealInFinder(_ template: Template) {
        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func openConfiguration() -> NSWorkspace.OpenConfiguration {
        let conf = NSWorkspace.OpenConfiguration()
        conf.hidesOthers = false
        conf.hides = false
        conf.activates = true
        return conf
    }
}
