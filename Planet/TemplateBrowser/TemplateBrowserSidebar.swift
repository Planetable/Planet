//
//  TemplateBrowserSidebar.swift
//  Planet
//
//  Created by Livid on 4/13/22.
//

import SwiftUI

struct TemplateBrowserSidebar: View {
    @StateObject var store = TemplateStore.shared
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
                    
                    Divider()

                    if hasTower() {
                        Button {
                            openTower(template)
                        } label: {
                            Text("Open in Tower")
                        }
                    }

                    Button {
                        openTerminal(template)
                    } label: {
                        Text("Open in Terminal")
                    }

                    if hasiTerm() {
                        Button {
                            openiTerm(template)
                        } label: {
                            Text("Open in iTerm")
                        }
                    }
                    
                    Divider()

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

    private func hasiTerm() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil
    }

    private func openiTerm(_ template: Template) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
        else { return }

        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: self.openConfiguration(), completionHandler: nil)
    }

    // TODO: Needs a general method for opening template in various installed apps.

    private func hasTower() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.fournova.Tower3") != nil
    }

    private func openTower(_ template: Template) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.fournova.Tower3")
        else { return }

        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: self.openConfiguration(), completionHandler: nil)
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

    private func openTerminal(_ template: Template) {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
        else { return }

        let url = URL(fileURLWithPath: template.path.path)

        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: self.openConfiguration(), completionHandler: nil)
    }

    private func openConfiguration() -> NSWorkspace.OpenConfiguration {
        let conf = NSWorkspace.OpenConfiguration()
        conf.hidesOthers = false
        conf.hides = false
        conf.activates = true
        return conf
    }
}
