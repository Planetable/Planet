//
//  TemplateBrowserStore.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import Foundation

class TemplateBrowserStore: ObservableObject {
    @Published var templates: [Template] = []
    
    init() {
        let templatesPath = PlanetManager.shared.templatesPath()
        do {
            let directories = try FileManager.default.listSubdirectories(url: templatesPath)
            for directory in directories {
                if let template = Template(url: directory) {
                    templates.append(template)
                }
            }
        } catch {
            debugPrint("Failed to load templates")
        }
    }
    
    subscript(templateID: Template.ID?) -> Template? {
        get {
            if let id = templateID {
                return templates.first(where: { $0.id == id }) ?? nil
            }
            return nil
        }
    }
}
