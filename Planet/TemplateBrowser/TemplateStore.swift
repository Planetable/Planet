import Foundation
import os
import PlanetSiteTemplates

class TemplateStore: ObservableObject {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TemplateStore")
    static let templatesPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Templates/
        let url = URLUtils.repoPath.appendingPathComponent("Templates", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    static let shared = TemplateStore()

    @Published var templates: [Template] = []

    func load() {
        do {
            let directories = try FileManager.default.contentsOfDirectory(
                at: Self.templatesPath,
                includingPropertiesForKeys: nil
            ).filter { $0.hasDirectoryPath }
            var templatesMapping: [String: Template] = [:]
            for directory in directories {
                if let template = Template.from(path: directory) {
                    templatesMapping[template.name] = template
                }
            }
            for builtInTemplate in PlanetSiteTemplates.builtInTemplates {
                var overwriteLocal = false
                if let existingTemplate = templatesMapping[builtInTemplate.name] {
                    if builtInTemplate.version != existingTemplate.version {
                        if existingTemplate.hasGitRepo {
                            Self.logger.info(
                                "Skip updating built-in template \(existingTemplate.name) because it has a git repo"
                            )
                        } else {
                            overwriteLocal = true
                        }
                    }
                } else {
                    overwriteLocal = true
                }
                if overwriteLocal {
                    Self.logger.info("Overwriting local built-in template \(builtInTemplate.name)")
                    let source = builtInTemplate.base!
                    let directoryName = source.lastPathComponent
                    let destination = Self.templatesPath.appendingPathComponent(directoryName, isDirectory: true)
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.copyItem(at: source, to: destination)
                    let newTemplate = Template.from(path: destination)!
                    templatesMapping[newTemplate.name] = newTemplate
                }
            }
            templates = Array(templatesMapping.values)
            templates.sort { t1, t2 in
                t1.name < t2.name
            }
            for template in templates {
                template.prepareTemporaryAssetsForPreview()
            }
        } catch {
            debugPrint("Failed to load templates: \(error)")
        }
    }

    func hasTemplate(named name: String) -> Bool {
        templates.contains(where: { $0.name == name })
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
