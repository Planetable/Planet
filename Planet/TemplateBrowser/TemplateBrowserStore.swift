//
//  TemplateBrowserStore.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import Foundation
import PlanetSiteTemplates

class TemplateBrowserStore: ObservableObject {
    static let shared = TemplateBrowserStore()

    @Published var templates: [Template] = []

    func loadTemplates() {
        do {
            let directories = try FileManager.default.listSubdirectories(url: URLUtils.templatesPath)
            var templatesMapping: [String: Template] = [:]
            for directory in directories {
                if let template = Template.from(url: directory) {
                    templatesMapping[template.name] = template
                }
            }
            for builtInTemplate in PlanetSiteTemplates.builtInTemplates {
                if let existingTemplate = templatesMapping[builtInTemplate.name] {
                    if builtInTemplate.version != existingTemplate.version {
                        if existingTemplate.hasGitRepo {
                            debugPrint("Skip updating built-in template \(existingTemplate.name) because it has a git repo")
                        } else {
                            let source = builtInTemplate.base!
                            let directoryName = source.lastPathComponent
                            let destination = URLUtils.templatesPath.appendingPathComponent(directoryName, isDirectory: true)
                            try FileManager.default.removeItem(at: destination)
                            try FileManager.default.copyItem(at: source, to: destination)
                            let newTemplate = Template.from(url: destination)!
                            templatesMapping[newTemplate.name] = newTemplate
                        }
                    }
                } else {
                    let source = builtInTemplate.base!
                    let directoryName = source.lastPathComponent
                    let destination = URLUtils.templatesPath.appendingPathComponent(directoryName, isDirectory: true)
                    try FileManager.default.copyItem(at: source, to: destination)
                    let newTemplate = Template.from(url: destination)!
                    templatesMapping[newTemplate.name] = newTemplate
                }
            }
            templates = Array(templatesMapping.values)
            templates.sort { t1, t2 in
                t1.name < t2.name
            }
        } catch {
            debugPrint("Failed to load templates: \(error)")
        }
    }

    subscript(templateID: Template.ID?) -> Template? {
        get {
            if let id = templateID {
                return templates.first(where: { $0.id == id })
            }
            return nil
        }
    }
}
