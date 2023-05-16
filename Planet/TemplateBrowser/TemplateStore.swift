import Foundation
import os
import PlanetSiteTemplates

class TemplateStore: ObservableObject {
    static let shared = TemplateStore()

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TemplateStore")

    @Published var templates: [Template] = []
    @Published var selectedTemplateID: Template.ID? {
        willSet(newValue) {
            UserDefaults.standard.set(newValue, forKey: String.selectedTemplateID)
        }
        didSet {
            NotificationCenter.default.post(name: .templateTitleSubtitleUpdated, object: nil)
        }
    }

    init() {
        do {
            try load()
            if let id = UserDefaults.standard.object(forKey: String.selectedTemplateID) as? Template.ID {
                selectedTemplateID = id
            }
        } catch {
            logger.error("Failed to load templates, cause: \(error.localizedDescription)")
        }
    }

    func load() throws {
        let templatesPath = URLUtils.repoPath().appendingPathComponent("Templates", isDirectory: true)
        try? FileManager.default.createDirectory(at: templatesPath, withIntermediateDirectories: true)
        let directories = try FileManager.default.contentsOfDirectory(
            at: templatesPath,
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
                        logger.info(
                            "Skip updating built-in template \(existingTemplate.name) because it has a git repo"
                        )
                    } else {
                        overwriteLocal = true
                    }
                }
                if let existingBuildNumber = existingTemplate.buildNumber, let builtInBuildNumber = builtInTemplate.buildNumber, existingBuildNumber < builtInBuildNumber {
                    if existingTemplate.hasGitRepo {
                        logger.info(
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
                logger.info("Overwriting local built-in template \(builtInTemplate.name)")
                let source = builtInTemplate.base!
                let directoryName = source.lastPathComponent
                let destination = templatesPath.appendingPathComponent(directoryName, isDirectory: true)
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
