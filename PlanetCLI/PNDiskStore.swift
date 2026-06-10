import AppKit
import Foundation

struct PNLibraryDoctorResult: Codable {
    let libraryPath: String
    let myPlanetsPathExists: Bool
    let publicPathExists: Bool
    let templatesPathExists: Bool
    let planetCount: Int
    let templateCount: Int
}

final class PNDiskStore {
    let root: URL
    private let fileManager = FileManager.default

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    var myPath: URL {
        root.appendingPathComponent("My", isDirectory: true)
    }

    var publicPath: URL {
        root.appendingPathComponent("Public", isDirectory: true)
    }

    var templatesPath: URL {
        root.appendingPathComponent("Templates", isDirectory: true)
    }

    func doctor() throws -> PNLibraryDoctorResult {
        PNLibraryDoctorResult(
            libraryPath: root.path,
            myPlanetsPathExists: fileManager.fileExists(atPath: myPath.path),
            publicPathExists: fileManager.fileExists(atPath: publicPath.path),
            templatesPathExists: fileManager.fileExists(atPath: templatesPath.path),
            planetCount: try planets(includeArchived: true, archivedOnly: false).count,
            templateCount: try templates().count
        )
    }

    func templates() throws -> [PNTemplateRecord] {
        guard fileManager.fileExists(atPath: templatesPath.path) else {
            return []
        }
        let directories = try fileManager.contentsOfDirectory(at: templatesPath, includingPropertiesForKeys: nil)
            .filter { $0.hasDirectoryPath }
        return directories.compactMap { directory in
            let info = directory.appendingPathComponent("template.json", isDirectory: false)
            guard let object = try? PNJSON.readObject(from: info) else { return nil }
            let name = (object["name"] as? String)?.pnNilIfEmpty ?? directory.lastPathComponent
            let version = object["version"] as? String
            let buildNumber = (object["buildNumber"] as? NSNumber)?.intValue ?? object["buildNumber"] as? Int
            return PNTemplateRecord(
                id: directory.lastPathComponent,
                name: name,
                version: version,
                buildNumber: buildNumber,
                path: directory.path
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func planets(includeArchived: Bool, archivedOnly: Bool) throws -> [PNPlanetRecord] {
        guard fileManager.fileExists(atPath: myPath.path) else {
            return []
        }
        let directories = try fileManager.contentsOfDirectory(at: myPath, includingPropertiesForKeys: nil)
            .filter { $0.hasDirectoryPath }
        var records = directories.compactMap { directory -> PNPlanetRecord? in
            try? PNJSON.read(PNPlanetRecord.self, from: planetInfoURL(for: directory.lastPathComponent))
        }
        if archivedOnly {
            records = records.filter(\.isArchived)
        } else if !includeArchived {
            records = records.filter { !$0.isArchived }
        }
        return sortPlanets(records)
    }

    func resolvePlanet(_ selector: String, includeArchived: Bool = true) throws -> PNPlanetRecord {
        let all = try planets(includeArchived: includeArchived, archivedOnly: false)
        let matches = PNSelector.planets(all, matching: selector)
        guard !matches.isEmpty else {
            throw PNError.notFound("Planet not found: \(selector)")
        }
        guard matches.count == 1 else {
            let candidates = matches.map { "\($0.id.uuidString)  \($0.name)" }.joined(separator: "\n")
            throw PNError.ambiguous("Planet selector is ambiguous:\n\(candidates)")
        }
        return matches[0]
    }

    func articles(for planet: PNPlanetRecord, includeAll: Bool) throws -> [PNArticleRecord] {
        let directory = articlesPath(for: planet.id)
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { !$0.hasDirectoryPath && $0.pathExtension == "json" }
        var records = files.compactMap { try? PNJSON.read(PNArticleRecord.self, from: $0) }
        if !includeAll {
            records = records.filter { $0.title.pnNilIfEmpty != nil || $0.content.pnNilIfEmpty != nil }
        }
        return records.sorted(by: sortArticles)
    }

    func resolveArticle(_ selector: String, in planet: PNPlanetRecord) throws -> PNArticleRecord {
        let all = try articles(for: planet, includeAll: true)
        let matches = PNSelector.articles(all, matching: selector, planet: planet)
        guard !matches.isEmpty else {
            throw PNError.notFound("Article not found: \(selector)")
        }
        guard matches.count == 1 else {
            let candidates = matches.map { article in
                "\(article.id.uuidString)  \(article.reference(in: planet) ?? "-")  \(article.title)"
            }.joined(separator: "\n")
            throw PNError.ambiguous("Article selector is ambiguous:\n\(candidates)")
        }
        return matches[0]
    }

    func planetBasePath(_ planet: PNPlanetRecord) -> URL {
        myPath.appendingPathComponent(planet.id.uuidString, isDirectory: true)
    }

    func planetPublicPath(_ planet: PNPlanetRecord) -> URL {
        publicPath.appendingPathComponent(planet.id.uuidString, isDirectory: true)
    }

    func articlePath(_ article: PNArticleRecord, in planet: PNPlanetRecord) -> URL {
        articlesPath(for: planet.id).appendingPathComponent("\(article.id.uuidString).json", isDirectory: false)
    }

    func articlePublicPath(_ article: PNArticleRecord, in planet: PNPlanetRecord) -> URL {
        planetPublicPath(planet).appendingPathComponent(article.id.uuidString, isDirectory: true)
    }

    func createPlanet(name: String, about: String, template requestedTemplate: String?, avatar: URL?) throws -> PNPlanetRecord {
        try ensureLibraryDirectories()
        let templateName = try resolvedTemplateName(requestedTemplate)
        let id = UUID()
        let now = Date()
        let ipns = try generateIPNSKey(named: id.uuidString)
        let record = PNPlanetRecord(
            id: id,
            name: name,
            about: about,
            nextArticleNumber: 1,
            ipns: ipns,
            created: now,
            updated: now,
            templateName: templateName,
            archived: false
        )

        try fileManager.createDirectory(at: planetBasePath(record), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: articlesPath(for: id), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: draftsPath(for: id), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: articleDraftsPath(for: id), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: planetPublicPath(record), withIntermediateDirectories: true)
        try PNJSON.write(record, to: planetInfoURL(for: id.uuidString))
        if let avatar {
            try writeAvatar(from: avatar, for: record)
        }
        try copyTemplateAssets(templateName: templateName, to: planetPublicPath(record))
        try writePublicPlanet(record)
        return record
    }

    func updatePlanet(_ planet: PNPlanetRecord, name: String?, about: String?, template: String?, avatar: URL?) throws -> PNPlanetRecord {
        let url = planetInfoURL(for: planet.id.uuidString)
        var object = try PNJSON.readObject(from: url)
        if let name { object["name"] = name }
        if let about { object["about"] = about }
        if let template {
            _ = try resolvedTemplateName(template)
            object["templateName"] = template
        }
        object["updated"] = PNJSON.dateNumber(Date())
        try PNJSON.writeObject(object, to: url)
        let updated = try PNJSON.read(PNPlanetRecord.self, from: url)
        if let avatar {
            try writeAvatar(from: avatar, for: updated)
        }
        if template != nil {
            try copyTemplateAssets(templateName: updated.templateName, to: planetPublicPath(updated))
        }
        try writePublicPlanet(updated)
        return updated
    }

    func deletePlanet(_ planet: PNPlanetRecord) throws -> PNPlanetRecord {
        try? fileManager.removeItem(at: planetBasePath(planet))
        try? fileManager.removeItem(at: planetPublicPath(planet))
        try? removeIPNSKey(named: planet.id.uuidString)
        return planet
    }

    func createArticle(planet: PNPlanetRecord, title: String, content: String, date: Date?, attachments: [URL]) throws -> PNArticleRecord {
        guard title.pnNilIfEmpty != nil || content.pnNilIfEmpty != nil else {
            throw PNError.usage("Article title or content is required.")
        }
        let id = UUID()
        let articleNumber = nextArticleNumber(for: planet)
        let created = date ?? Date()
        let publicBase = planetPublicPath(planet).appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: publicBase, withIntermediateDirectories: true)
        let copied = try copyAttachments(attachments, into: publicBase, existing: [], replace: false)
        let article = PNArticleRecord(
            id: id,
            articleType: 0,
            link: "/\(id.uuidString)/",
            articleNumber: articleNumber,
            title: title,
            content: content,
            summary: summary(from: content),
            created: created,
            starType: 0,
            videoFilename: copied.video,
            audioFilename: copied.audio,
            attachments: copied.names,
            cids: [:],
            tags: [:]
        )
        try PNJSON.write(article, to: articlePath(article, in: planet))
        try writePublicArticle(article, planet: planet)
        try updatePlanetNextArticleNumber(planet, next: articleNumber + 1)
        try writePublicPlanet(for: planet.id)
        return article
    }

    func updateArticle(
        planet: PNPlanetRecord,
        article: PNArticleRecord,
        title: String?,
        content: String?,
        date: Date?,
        replaceAttachments: Bool,
        attachments: [URL]
    ) throws -> PNArticleRecord {
        let url = articlePath(article, in: planet)
        var object = try PNJSON.readObject(from: url)
        if let title { object["title"] = title }
        if let content {
            object["content"] = content
            object["summary"] = summary(from: content)
            object["contentRendered"] = NSNull()
        }
        if let date { object["created"] = PNJSON.dateNumber(date) }
        object["modified"] = PNJSON.dateNumber(Date())

        let publicBase = articlePublicPath(article, in: planet)
        try fileManager.createDirectory(at: publicBase, withIntermediateDirectories: true)
        let existing = (object["attachments"] as? [String]) ?? article.attachments ?? []
        if replaceAttachments || !attachments.isEmpty {
            let copied = try copyAttachments(attachments, into: publicBase, existing: existing, replace: replaceAttachments)
            object["attachments"] = copied.names
            if let video = copied.video {
                object["videoFilename"] = video
            } else {
                object["videoFilename"] = NSNull()
            }
            if let audio = copied.audio {
                object["audioFilename"] = audio
            } else {
                object["audioFilename"] = NSNull()
            }
            object["cids"] = [:]
        }

        try PNJSON.writeObject(object, to: url)
        let updated = try PNJSON.read(PNArticleRecord.self, from: url)
        try writePublicArticle(updated, planet: planet)
        try touchPlanetUpdated(planet)
        try writePublicPlanet(for: planet.id)
        return updated
    }

    func deleteArticle(planet: PNPlanetRecord, article: PNArticleRecord) throws -> PNArticleRecord {
        try? fileManager.removeItem(at: articlePath(article, in: planet))
        try? fileManager.removeItem(at: articlePublicPath(article, in: planet))
        var planetObject = try PNJSON.readObject(from: planetInfoURL(for: planet.id.uuidString))
        planetObject["updated"] = PNJSON.dateNumber(Date())
        try PNJSON.writeObject(planetObject, to: planetInfoURL(for: planet.id.uuidString))
        try writePublicPlanet(for: planet.id)
        return article
    }

    func search(query: String, limit: Int, planetFilter: PNPlanetRecord?) throws -> PNSearchResponse {
        let planetsToSearch: [PNPlanetRecord]
        if let planetFilter {
            planetsToSearch = [planetFilter]
        } else {
            planetsToSearch = try planets(includeArchived: false, archivedOnly: false)
        }
        let matchingPlanets = planetsToSearch
            .filter { $0.name.pnCaseInsensitiveContains(query) || $0.about.pnCaseInsensitiveContains(query) }
            .map { PNSearchPlanet(id: $0.id, name: $0.name, about: $0.about, created: $0.created, updated: $0.updated) }

        var matchingArticles: [PNSearchArticle] = []
        for planet in planetsToSearch {
            for article in try articles(for: planet, includeAll: true) where articleMatches(article, query: query) {
                matchingArticles.append(
                    PNSearchArticle(
                        articleID: article.id,
                        articleCreated: article.created,
                        articleNumber: article.articleNumber,
                        articleReference: article.reference(in: planet),
                        title: article.title,
                        preview: preview(for: article, query: query),
                        planetID: planet.id,
                        planetName: planet.name,
                        relevanceScore: nil,
                        bm25Score: nil,
                        vectorScore: nil,
                        source: "disk"
                    )
                )
            }
        }
        return PNSearchResponse(planets: matchingPlanets, articles: Array(matchingArticles.prefix(max(1, limit))))
    }

    private func ensureLibraryDirectories() throws {
        try fileManager.createDirectory(at: myPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: publicPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: templatesPath, withIntermediateDirectories: true)
    }

    private func sortPlanets(_ planets: [PNPlanetRecord]) -> [PNPlanetRecord] {
        return planets.sorted { lhs, rhs in
            if lhs.created != rhs.created {
                return lhs.created > rhs.created
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func sortArticles(_ lhs: PNArticleRecord, _ rhs: PNArticleRecord) -> Bool {
        switch (lhs.pinned, rhs.pinned) {
        case (nil, nil):
            return lhs.created > rhs.created
        case (nil, _):
            return false
        case (_, nil):
            return true
        case let (.some(lhsPinned), .some(rhsPinned)):
            return lhsPinned > rhsPinned
        }
    }

    private func resolvedTemplateName(_ requested: String?) throws -> String {
        let available = try templates()
        if let requested = requested?.pnNilIfEmpty {
            guard available.contains(where: { $0.name.pnCaseInsensitiveEquals(requested) }) else {
                throw PNError.notFound("Template not found: \(requested)")
            }
            return available.first(where: { $0.name.pnCaseInsensitiveEquals(requested) })?.name ?? requested
        }
        if let sepia = available.first(where: { $0.name == "Sepia" }) {
            return sepia.name
        }
        return available.first?.name ?? "Sepia"
    }

    private func copyTemplateAssets(templateName: String, to publicBase: URL) throws {
        guard let template = try templates().first(where: { $0.name.pnCaseInsensitiveEquals(templateName) }) else {
            return
        }
        let assets = URL(fileURLWithPath: template.path, isDirectory: true).appendingPathComponent("assets", isDirectory: true)
        guard fileManager.fileExists(atPath: assets.path) else { return }
        try copyReplacing(assets, to: publicBase.appendingPathComponent("assets", isDirectory: true))
    }

    private func nextArticleNumber(for planet: PNPlanetRecord) -> Int {
        let existing = (try? articles(for: planet, includeAll: true).compactMap(\.articleNumber).max()) ?? 0
        return max(planet.nextArticleNumber ?? 1, existing + 1)
    }

    private func updatePlanetNextArticleNumber(_ planet: PNPlanetRecord, next: Int) throws {
        let url = planetInfoURL(for: planet.id.uuidString)
        var object = try PNJSON.readObject(from: url)
        object["nextArticleNumber"] = next
        object["updated"] = PNJSON.dateNumber(Date())
        try PNJSON.writeObject(object, to: url)
    }

    private func touchPlanetUpdated(_ planet: PNPlanetRecord) throws {
        let url = planetInfoURL(for: planet.id.uuidString)
        var object = try PNJSON.readObject(from: url)
        object["updated"] = PNJSON.dateNumber(Date())
        try PNJSON.writeObject(object, to: url)
    }

    private func copyAttachments(_ attachments: [URL], into publicBase: URL, existing: [String], replace: Bool) throws -> (names: [String], video: String?, audio: String?) {
        if replace {
            for name in existing {
                try? fileManager.removeItem(at: publicBase.appendingPathComponent(name, isDirectory: false))
            }
        }
        var names = replace ? [] : existing
        for attachment in attachments {
            let name = attachment.lastPathComponent
            let target = publicBase.appendingPathComponent(name, isDirectory: false)
            try copyReplacing(attachment, to: target)
            if !names.contains(name) {
                names.append(name)
            }
        }
        let video = names.first(where: isVideo)
        let audio = names.first(where: isAudio)
        return (names, video, audio)
    }

    private func publicArticleRecord(from article: PNArticleRecord, planet: PNPlanetRecord) -> PNPublicArticleRecord {
        PNPublicArticleRecord(
            articleType: article.articleType ?? 0,
            id: article.id,
            link: article.link,
            slug: article.slug,
            articleNumber: article.articleNumber,
            articleReference: article.reference(in: planet),
            externalLink: article.externalLink,
            title: article.title,
            content: article.content,
            contentRendered: article.contentRendered,
            created: article.created,
            modified: article.modified,
            hasVideo: article.videoFilename != nil,
            videoFilename: article.videoFilename,
            hasAudio: article.audioFilename != nil,
            audioFilename: article.audioFilename,
            audioDuration: nil,
            audioByteLength: nil,
            attachments: article.attachments,
            heroImage: article.heroImage,
            heroImageWidth: article.heroImageWidth,
            heroImageHeight: article.heroImageHeight,
            heroImageURL: nil,
            heroImageFilename: article.heroImage,
            cids: article.cids,
            tags: article.tags,
            pinned: article.pinned
        )
    }

    private func writePublicArticle(_ article: PNArticleRecord, planet: PNPlanetRecord) throws {
        let publicBase = articlePublicPath(article, in: planet)
        try fileManager.createDirectory(at: publicBase, withIntermediateDirectories: true)
        let publicArticle = publicArticleRecord(from: article, planet: planet)
        try PNJSON.write(publicArticle, to: publicBase.appendingPathComponent("article.json", isDirectory: false))
    }

    private func writePublicPlanet(for planetID: UUID) throws {
        let planet = try PNJSON.read(PNPlanetRecord.self, from: planetInfoURL(for: planetID.uuidString))
        try writePublicPlanet(planet)
    }

    private func writePublicPlanet(_ planet: PNPlanetRecord) throws {
        try fileManager.createDirectory(at: planetPublicPath(planet), withIntermediateDirectories: true)
        let publicArticles = try articles(for: planet, includeAll: true)
            .map { publicArticleRecord(from: $0, planet: planet) }
        let publicPlanet = PNPublicPlanetRecord(
            id: planet.id,
            name: planet.name,
            about: planet.about,
            ipns: planet.ipns,
            created: planet.created,
            updated: planet.updated,
            articles: publicArticles,
            plausibleEnabled: planet.plausibleEnabled,
            plausibleDomain: planet.plausibleDomain,
            plausibleAPIServer: planet.plausibleAPIServer,
            juiceboxEnabled: planet.juiceboxEnabled,
            juiceboxProjectID: planet.juiceboxProjectID,
            juiceboxProjectIDGoerli: planet.juiceboxProjectIDGoerli,
            acceptsDonation: planet.acceptsDonation,
            acceptsDonationMessage: planet.acceptsDonationMessage,
            acceptsDonationETHAddress: planet.acceptsDonationETHAddress,
            twitterUsername: planet.twitterUsername,
            githubUsername: planet.githubUsername,
            telegramUsername: planet.telegramUsername,
            mastodonUsername: planet.mastodonUsername,
            discordLink: planet.discordLink,
            podcastCategories: planet.podcastCategories,
            podcastLanguage: planet.podcastLanguage,
            podcastExplicit: planet.podcastExplicit,
            tags: planet.tags
        )
        try PNJSON.write(publicPlanet, to: publicPlanetInfoURL(for: planet.id.uuidString))
    }

    private func generateIPNSKey(named name: String) throws -> String {
        let executable = try bundledIPFSExecutable()
        try ensureIPFSRepository(using: executable)
        let result = try runIPFS(arguments: ["key", "gen", "-t", "ed25519", name], executable: executable, timeout: 15)
        guard result.status == 0, !result.output.isEmpty else {
            throw PNError.diskError("Failed to generate IPFS key for \(name). \(result.error)")
        }
        return result.output
    }

    private func removeIPNSKey(named name: String) throws {
        let executable = try bundledIPFSExecutable()
        let config = PNPreferences.ipfsRepositoryURL.appendingPathComponent("config", isDirectory: false)
        guard fileManager.fileExists(atPath: config.path) else { return }
        _ = try runIPFS(arguments: ["key", "rm", name], executable: executable, timeout: 15)
    }

    private func bundledIPFSExecutable() throws -> URL {
        if let executable = PNPreferences.ipfsExecutableOverrideURL {
            guard fileManager.fileExists(atPath: executable.path) else {
                throw PNError.diskError("Missing IPFS executable override at \(executable.path).")
            }
            return executable
        }
        guard let resources = PNAppBridge.appResourcesURL else {
            throw PNError.diskError("Cannot locate Planet.app resources for the bundled IPFS executable. Use API mode or run the bundled pn helper.")
        }
        #if arch(arm64)
        let executable = resources.appendingPathComponent("ipfs-arm64-0.15.bin", isDirectory: false)
        #else
        let executable = resources.appendingPathComponent("ipfs-amd64-0.15.bin", isDirectory: false)
        #endif
        guard fileManager.fileExists(atPath: executable.path) else {
            throw PNError.diskError("Missing bundled IPFS executable at \(executable.path).")
        }
        return executable
    }

    private func ensureIPFSRepository(using executable: URL) throws {
        try fileManager.createDirectory(at: PNPreferences.ipfsRepositoryURL, withIntermediateDirectories: true)
        let config = PNPreferences.ipfsRepositoryURL.appendingPathComponent("config", isDirectory: false)
        guard !fileManager.fileExists(atPath: config.path) else { return }
        let result = try runIPFS(arguments: ["init"], executable: executable, timeout: 20)
        guard result.status == 0 else {
            throw PNError.diskError("Failed to initialize IPFS repository. \(result.error)")
        }
    }

    private func runIPFS(arguments: [String], executable: URL, timeout: TimeInterval) throws -> (status: Int32, output: String, error: String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["IPFS_PATH"] = PNPreferences.ipfsRepositoryURL.path
        process.environment = environment
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            let command = (["ipfs"] + arguments).joined(separator: " ")
            throw PNError.diskError("Timed out running \(command).")
        }
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.pnTrimmed ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.pnTrimmed ?? ""
        return (process.terminationStatus, output, error)
    }

    private func copyReplacing(_ source: URL, to target: URL) throws {
        try? fileManager.removeItem(at: target)
        try fileManager.copyItem(at: source, to: target)
    }

    private func writeAvatar(from source: URL, for planet: PNPlanetRecord) throws {
        guard let image = NSImage(contentsOf: source),
              let avatarData = resizedPNGData(from: image, maxLength: 144)
        else {
            throw PNError.diskError("Unable to read avatar image at \(source.path).")
        }

        let privateBase = planetBasePath(planet)
        let publicBase = planetPublicPath(planet)
        try fileManager.createDirectory(at: privateBase, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: publicBase, withIntermediateDirectories: true)
        try avatarData.write(to: privateBase.appendingPathComponent("avatar.png", isDirectory: false), options: .atomic)
        try avatarData.write(to: publicBase.appendingPathComponent("avatar.png", isDirectory: false), options: .atomic)

        guard let faviconData = resizedPNGData(from: image, maxLength: 32) else {
            return
        }
        try faviconData.write(to: privateBase.appendingPathComponent("favicon.ico", isDirectory: false), options: .atomic)
        try faviconData.write(to: publicBase.appendingPathComponent("favicon.ico", isDirectory: false), options: .atomic)
    }

    private func resizedPNGData(from image: NSImage, maxLength: Int) -> Data? {
        let sourceRect = largestCenterSquare(for: image)
        let resizeLength = min(maxLength, Int(sourceRect.width))
        guard resizeLength > 0,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: resizeLength,
                pixelsHigh: resizeLength,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              )
        else {
            return nil
        }

        let resizeSize = NSSize(width: resizeLength, height: resizeLength)
        let targetRect = NSRect(origin: .zero, size: resizeSize)
        bitmap.size = resizeSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: targetRect, from: sourceRect, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }

    private func largestCenterSquare(for image: NSImage) -> NSRect {
        let width = image.size.width
        let height = image.size.height
        let length = min(width, height)
        return NSRect(x: (width - length) / 2, y: (height - length) / 2, width: length, height: length)
    }

    private func planetInfoURL(for id: String) -> URL {
        myPath.appendingPathComponent(id, isDirectory: true).appendingPathComponent("planet.json", isDirectory: false)
    }

    private func publicPlanetInfoURL(for id: String) -> URL {
        publicPath.appendingPathComponent(id, isDirectory: true).appendingPathComponent("planet.json", isDirectory: false)
    }

    private func articlesPath(for planetID: UUID) -> URL {
        myPath.appendingPathComponent(planetID.uuidString, isDirectory: true).appendingPathComponent("Articles", isDirectory: true)
    }

    private func draftsPath(for planetID: UUID) -> URL {
        myPath.appendingPathComponent(planetID.uuidString, isDirectory: true).appendingPathComponent("Drafts", isDirectory: true)
    }

    private func articleDraftsPath(for planetID: UUID) -> URL {
        articlesPath(for: planetID).appendingPathComponent("Drafts", isDirectory: true)
    }

    private func summary(from content: String) -> String? {
        let collapsed = content.replacingOccurrences(of: "\n", with: " ").pnTrimmed
        guard !collapsed.isEmpty else { return nil }
        if collapsed.count > 280 {
            return String(collapsed.prefix(280)) + "..."
        }
        return collapsed
    }

    private func articleMatches(_ article: PNArticleRecord, query: String) -> Bool {
        if article.title.pnCaseInsensitiveContains(query) { return true }
        if article.content.pnCaseInsensitiveContains(query) { return true }
        if article.slug?.pnCaseInsensitiveContains(query) == true { return true }
        if article.tags?.keys.contains(where: { $0.pnCaseInsensitiveContains(query) }) == true { return true }
        if article.tags?.values.contains(where: { $0.pnCaseInsensitiveContains(query) }) == true { return true }
        if article.attachments?.contains(where: { $0.pnCaseInsensitiveContains(query) }) == true { return true }
        return false
    }

    private func preview(for article: PNArticleRecord, query: String) -> String {
        let text = article.content.replacingOccurrences(of: "\n", with: " ")
        if let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            let prefixStart = text.distance(from: text.startIndex, to: range.lowerBound)
            let startOffset = max(0, prefixStart - 60)
            let endOffset = min(text.count, prefixStart + query.count + 120)
            let start = text.index(text.startIndex, offsetBy: startOffset)
            let end = text.index(text.startIndex, offsetBy: endOffset)
            return String(text[start..<end]).pnTrimmed
        }
        return String(text.prefix(180)).pnTrimmed
    }

    private func isVideo(_ name: String) -> Bool {
        ["mp4", "m4v", "mov", "avi", "mpeg", "mpg", "webm"].contains((name as NSString).pathExtension.lowercased())
    }

    private func isAudio(_ name: String) -> Bool {
        ["aac", "mp3", "m4a", "ogg", "wav", "webm"].contains((name as NSString).pathExtension.lowercased())
    }
}
