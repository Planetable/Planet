import Foundation
import PlanetSiteTemplates
import os
import UserNotifications

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

    private var monitors: [TemplateMonitor] = []

    init() {
        do {
            try load()
            if let id = UserDefaults.standard.object(forKey: String.selectedTemplateID)
                as? Template.ID
            {
                selectedTemplateID = id
            }
        }
        catch {
            logger.error("Failed to load templates, cause: \(error.localizedDescription)")
        }
    }

    deinit {
        monitors.removeAll()
    }

    func load() throws {
        let templatesPath = URLUtils.repoPath().appendingPathComponent(
            "Templates",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: templatesPath,
            withIntermediateDirectories: true
        )
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
                            "Skip updating existing template \(existingTemplate.name) because it has a git repo"
                        )
                        overwriteLocal = false
                    }
                    else {
                        logger.info(
                            "Updating existing template \(existingTemplate.name) from version \(existingTemplate.version) to \(builtInTemplate.version)"
                        )
                        overwriteLocal = true
                    }
                }
                else {
                    overwriteLocal = false
                    logger.info(
                        "No need to update existing template \(existingTemplate.name) (version: \(existingTemplate.version))"
                    )
                }
                if let existingBuildNumber = existingTemplate.buildNumber,
                    let builtInBuildNumber = builtInTemplate.buildNumber,
                    existingBuildNumber < builtInBuildNumber
                {
                    if existingTemplate.hasGitRepo {
                        logger.info(
                            "Skip updating existing template \(existingTemplate.name) because it has a git repo"
                        )
                        overwriteLocal = false
                    }
                    else {
                        logger.info(
                            "Updating existing template \(existingTemplate.name) from buildNumber \(existingTemplate.buildNumber ?? 0) to \(builtInTemplate.buildNumber ?? 0)"
                        )
                        overwriteLocal = true
                    }
                }
                else {
                    logger.info(
                        "No need to update existing template \(existingTemplate.name) (buildNumber: \(existingTemplate.buildNumber ?? 0))"
                    )
                }
            }
            else {
                // No local template, overwrite
                overwriteLocal = true
            }
            if overwriteLocal {
                logger.info("Overwriting local built-in template \(builtInTemplate.name)")
                let source = builtInTemplate.base!
                let directoryName = source.lastPathComponent
                let destination = templatesPath.appendingPathComponent(
                    directoryName,
                    isDirectory: true
                )
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
            let monitor = TemplateMonitor(byID: template.id) {
                self.reloadTemplate(byID: template.id)
            }
            do {
                try monitor.startMonitoring()
                monitors.append(monitor)
            } catch {
                debugPrint("failed to start template monitoring: \(error)")
            }
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

    private func reloadTemplate(byID id: Template.ID) {
        // template.json has changes, select and reload it locally.
        let templatesPath = URLUtils.repoPath().appendingPathComponent(
            "Templates",
            isDirectory: true
        )
        let targetTemplatePath = templatesPath.appendingPathComponent(id)
        guard FileManager.default.fileExists(atPath: targetTemplatePath.path) else { return }
        let updatedTemplates: [Template] = templates.map { t in
            if t.id == id, let tt = Template.from(path: targetTemplatePath) {
                tt.prepareTemporaryAssetsForPreview()
                return tt
            } else {
                return t
            }
        }
        Task { @MainActor in
            self.templates = updatedTemplates.sorted(by: { $0.name < $1.name })
            if self.selectedTemplateID != id {
                self.selectedTemplateID = id
            }
            NotificationCenter.default.post(name: .refreshTemplatePreview, object: nil)
            NotificationCenter.default.post(name: .templateTitleSubtitleUpdated, object: nil)
            let notification = UNMutableNotificationContent()
            notification.title = "Template \(id) Reloaded"
            notification.interruptionLevel = .active
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: notification,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
