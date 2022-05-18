//
//  TemplateBrowserStore.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import Foundation

class TemplateBrowserStore: ObservableObject {
    static let bundledTemplates = ["plain"]

    static let shared = TemplateBrowserStore()

    @Published var templates: [Template] = []

    func loadTemplates() {
        templates.removeAll()
        var templatesToCopy = TemplateBrowserStore.bundledTemplates
        do {
            let directories = try FileManager.default.listSubdirectories(url: URLUtils.templatesPath)
            for directory in directories {
                if var template = Template.from(url: directory) {
                    let directoryName = directory.lastPathComponent
                    if templatesToCopy.contains(directoryName) {
                        let bundledDirectory = Bundle.main.url(forResource: directoryName, withExtension: nil)!
                        let bundledTemplate = Template.from(url: bundledDirectory)!
                        if template.version != bundledTemplate.version {
                            try FileManager.default.removeItem(at: directory)
                            try FileManager.default.copyItem(at: bundledDirectory, to: directory)
                            template = Template.from(url: directory)!
                        }
                        templatesToCopy.removeAll { name in
                            name == directoryName
                        }
                    }
                    templates.append(template)
                }
            }
            for name in templatesToCopy {
                let bundledDirectory = Bundle.main.url(forResource: name, withExtension: nil)!
                let directory = URLUtils.templatesPath.appendingPathComponent(name, isDirectory: true)
                try FileManager.default.copyItem(at: bundledDirectory, to: directory)
                let template = Template.from(url: directory)!
                templates.append(template)
            }
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
