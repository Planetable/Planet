//
//  TemplateBrowserView.swift
//  Planet
//
//  Created by Xin Liu on 4/13/22.
//

import SwiftUI

struct TemplateBrowserView: View {
    @EnvironmentObject var templateStore: TemplateStore
    @AppStorage("TemplateBrowserView.selectedTemplateID") private var selectedTemplateID: Template.ID?

    var template: Template? {
        templateStore[selectedTemplateID]
    }

    var body: some View {
        NavigationView {
            TemplateBrowserSidebar(selection: $selectedTemplateID)
            TemplatePreviewView(templateId: $selectedTemplateID)
                .navigationTitle(template?.name ?? "Template Browser")
                .navigationSubtitle(navigationSubtitle())
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Spacer()

                        if hasVSCode() {
                            Button {
                                openVSCode()
                            } label: {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                            }.help("Open in VSCode")
                        }

                        Button {
                            revealInFinder()
                        } label: {
                            Image(systemName: "folder")
                        }.help("Reveal in Finder")

                        Button {
                            refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }.help("Refresh")
                    }
                }
        }
    }

    private func hasVSCode() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil
    }

    private func openVSCode() {
        guard
            let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
        else { return }
        guard let template = template else { return }

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

    private func revealInFinder() {
        guard let template = template else { return }
        let url = URL(fileURLWithPath: template.path.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func refresh() {
        NotificationCenter.default.post(name: .refreshTemplatePreview, object: nil)
    }

    private func navigationSubtitle() -> String {
        if let template = template {
            return "\(template.author) · Version \(template.version)"
        } else {
            return ""
        }
    }
}

struct TemplateBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateBrowserView()
    }
}
