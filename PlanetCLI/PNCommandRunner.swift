import Darwin
import Foundation

enum PNBackend {
    case api(PNAPIClient)
    case disk(PNDiskStore)
}

struct PNArguments {
    var values: [String]

    var isEmpty: Bool {
        values.isEmpty
    }

    mutating func pop() -> String? {
        values.isEmpty ? nil : values.removeFirst()
    }

    mutating func require(_ name: String) throws -> String {
        guard let value = pop(), !value.hasPrefix("--") else {
            throw PNError.usage("Missing \(name).")
        }
        return value
    }

    mutating func flag(_ name: String) -> Bool {
        if let index = values.firstIndex(of: name) {
            values.remove(at: index)
            return true
        }
        return false
    }

    mutating func option(_ name: String) throws -> String? {
        guard let index = values.firstIndex(of: name) else { return nil }
        values.remove(at: index)
        guard index < values.count else {
            throw PNError.usage("Missing value for \(name).")
        }
        return values.remove(at: index)
    }

    mutating func repeatedOption(_ name: String) throws -> [String] {
        var result: [String] = []
        while let value = try option(name) {
            result.append(value)
        }
        return result
    }

    /// Consume and return all remaining positional values (no leading "--").
    mutating func popRemaining() -> [String] {
        let positional = values.filter { !$0.hasPrefix("--") }
        values.removeAll { !$0.hasPrefix("--") }
        return positional
    }

    func ensureNoExtras() throws {
        guard values.isEmpty else {
            throw PNError.usage("Unexpected arguments: \(values.joined(separator: " "))")
        }
    }
}

final class PNCommandRunner {
    let options: PNGlobalOptions
    private var ensuredClient: PNAPIClient?
    lazy var disk: PNDiskStore = {
        PNDiskStore(root: PNPreferences.libraryURL(override: options.libraryOverride))
    }()

    init(options: PNGlobalOptions) {
        self.options = options
    }

    private static var currentVersion: String {
        versionString(appInfo: PNAppBridge.appInfoDictionary, bundleInfo: Bundle.main.infoDictionary)
    }

    static func versionString(appInfo: [String: Any]?, bundleInfo: [String: Any]?) -> String {
        version(in: appInfo) ?? version(in: bundleInfo) ?? "unknown"
    }

    private static func version(in info: [String: Any]?) -> String? {
        for key in ["CFBundleShortVersionString", "CFBundleVersion"] {
            guard let value = info?[key] as? String else { continue }
            let version = value.pnTrimmed
            if !version.isEmpty {
                return version
            }
        }
        return nil
    }

    static func run(rawArguments: [String]) -> Int32 {
        do {
            let parsed = try parseGlobalOptions(rawArguments)
            let runner = PNCommandRunner(options: parsed.options)
            try runner.run(arguments: parsed.arguments)
            return 0
        } catch let error as PNError {
            FileHandle.standardError.write(Data("pn: \(error.description)\n".utf8))
            return 2
        } catch {
            FileHandle.standardError.write(Data("pn: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    static func parseGlobalOptions(_ raw: [String]) throws -> (options: PNGlobalOptions, arguments: [String]) {
        var options = PNGlobalOptions()
        var remaining: [String] = []
        var index = 0
        while index < raw.count {
            let arg = raw[index]
            switch arg {
            case "--json":
                options.outputJSON = true
            case "--pretty":
                options.prettyJSON = true
            case "--library":
                index += 1
                guard index < raw.count else { throw PNError.usage("Missing value for --library.") }
                options.libraryOverride = URL(fileURLWithPath: raw[index], isDirectory: true)
            case "--api-url":
                index += 1
                guard index < raw.count, let url = URL(string: raw[index]) else {
                    throw PNError.usage("Missing or invalid value for --api-url.")
                }
                options.apiURLOverride = url
            case "--source":
                index += 1
                guard index < raw.count, let source = PNSourceMode(rawValue: raw[index]) else {
                    throw PNError.usage("Expected --source auto|api|disk.")
                }
                options.source = source
            case "--timeout":
                index += 1
                guard index < raw.count, let timeout = TimeInterval(raw[index]), timeout > 0 else {
                    throw PNError.usage("Expected positive seconds for --timeout.")
                }
                options.timeout = timeout
            case "--version":
                remaining.append("version")
            case "--help", "-h":
                remaining.append("help")
            default:
                remaining.append(arg)
            }
            index += 1
        }
        return (options, remaining)
    }

    func run(arguments raw: [String]) throws {
        var arguments = PNArguments(values: raw.isEmpty ? ["help"] : raw)
        guard let command = arguments.pop() else {
            print(helpText())
            return
        }
        switch command {
        case "help":
            print(helpText(topic: arguments.pop()))
        case "version":
            try arguments.ensureNoExtras()
            let version = Self.currentVersion
            emit(["pn": version], human: "pn \(version)")
        case "install":
            try runInstall(arguments: arguments)
        case "status":
            try arguments.ensureNoExtras()
            try runStatus()
        case "api":
            try runAPI(arguments: arguments)
        case "library":
            try runLibrary(arguments: arguments)
        case "template":
            try runTemplate(arguments: arguments)
        case "planet":
            try runPlanet(arguments: arguments)
        case "article":
            try runArticle(arguments: arguments)
        case "search":
            try runSearch(arguments: arguments)
        default:
            throw PNError.usage("Unknown command: \(command)")
        }
    }

    private func runInstall(arguments input: PNArguments) throws {
        var arguments = input
        let explicitDestination = try arguments.option("--to")
        let installDirectory = defaultInstallDirectory()
        let to = explicitDestination ?? installDirectory.path
        let force = arguments.flag("--force")
        try arguments.ensureNoExtras()

        let source = PNAppBridge.executableURL
        let targetBase = URL(fileURLWithPath: NSString(string: to).expandingTildeInPath)
        let target = targetBase.lastPathComponent == "pn" ? targetBase : targetBase.appendingPathComponent("pn", isDirectory: false)
        let existingSymbolicLink = existingSymbolicLinkDestination(at: target)
        let targetExists = FileManager.default.fileExists(atPath: target.path) || existingSymbolicLink != nil
        var didLink = false
        if targetExists {
            if force {
                try FileManager.default.removeItem(at: target)
            }
            else if let existingSymbolicLink {
                // Relink anything that does not already point at this executable,
                // including stale links left by moved or removed app copies.
                let destination = symbolicLinkDestinationURL(existingSymbolicLink, relativeTo: target)
                if destination.resolvingSymlinksInPath().path != source.path {
                    try FileManager.default.removeItem(at: target)
                }
            }
            else {
                throw PNError.diskError("\(target.path) already exists. Re-run with --force to replace it.")
            }
        }
        if !FileManager.default.fileExists(atPath: target.path) && existingSymbolicLinkDestination(at: target) == nil {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
            didLink = true
        }
        let shouldUpdateShellProfile = target.deletingLastPathComponent().standardizedFileURL.path == installDirectory.standardizedFileURL.path
        let didUpdateShellProfile = shouldUpdateShellProfile
            ? try ensureZshProfileContainsInstallPath(installDirectory)
            : false
        let result = PNInstallResult(source: source.path, target: target.path)
        var lines = didLink
            ? ["Linked \(target.path) -> \(source.path)"]
            : ["Link already up to date at \(target.path) -> \(source.path)"]
        if didUpdateShellProfile {
            lines.append("Updated ~/.zprofile to include \(target.deletingLastPathComponent().path) in PATH")
        }
        emit(result, human: lines.joined(separator: "\n"))
    }

    private func defaultInstallDirectory() -> URL {
        realHomeDirectory().appendingPathComponent(".local/bin", isDirectory: true)
    }

    // When spawned from the sandboxed app, HOME points to the app container;
    // resolve the user's real home directory instead.
    private func realHomeDirectory() -> URL {
        if let home = getpwuid(getuid())?.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func existingSymbolicLinkDestination(at url: URL) -> String? {
        try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)
    }

    private func symbolicLinkDestinationURL(_ destination: String, relativeTo linkURL: URL) -> URL {
        let destinationURL = destination.hasPrefix("/")
            ? URL(fileURLWithPath: destination)
            : linkURL.deletingLastPathComponent().appendingPathComponent(destination)
        return destinationURL.standardizedFileURL
    }

    private func ensureZshProfileContainsInstallPath(_ installDirectory: URL) throws -> Bool {
        if try zshPATHContainsInstallDirectory(installDirectory) {
            return false
        }

        let profileURL = realHomeDirectory()
            .appendingPathComponent(".zprofile", isDirectory: false)
        let commentLine = "# Added by Planet to make the pn CLI available in Terminal."
        let exportLine = #"export PATH="$HOME/.local/bin:$PATH""#
        var contents = ""

        if FileManager.default.fileExists(atPath: profileURL.path) {
            contents = try String(contentsOf: profileURL, encoding: .utf8)
            if contents.contains(exportLine) {
                return false
            }
        }

        if !contents.isEmpty && !contents.hasSuffix("\n") {
            contents.append("\n")
        }
        if !contents.isEmpty {
            contents.append("\n")
        }
        contents.append(commentLine)
        contents.append("\n")
        contents.append(exportLine)
        contents.append("\n")

        try contents.write(to: profileURL, atomically: true, encoding: .utf8)
        return true
    }

    private func zshPATHContainsInstallDirectory(_ installDirectory: URL) throws -> Bool {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let pathMarkerStart = "__PLANET_PN_PATH_START__"
        let pathMarkerEnd = "__PLANET_PN_PATH_END__"
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            "-lic",
            #"printf "\n__PLANET_PN_PATH_START__%s__PLANET_PN_PATH_END__\n" "$PATH""#,
        ]
        process.environment = [
            "HOME": realHomeDirectory().path,
            "LOGNAME": NSUserName(),
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "SHELL": "/bin/zsh",
            "USER": NSUserName(),
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let error = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw PNError.diskError(error?.pnNilIfEmpty ?? output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard
            let pathStartRange = output.range(of: pathMarkerStart),
            let pathEndRange = output.range(of: pathMarkerEnd, range: pathStartRange.upperBound..<output.endIndex)
        else {
            throw PNError.diskError("Could not read shell PATH.")
        }
        let path = String(output[pathStartRange.upperBound..<pathEndRange.lowerBound])
        return pathList(path, contains: installDirectory)
    }

    private func pathList(_ pathList: String, contains targetURL: URL) -> Bool {
        let targetPath = targetURL.standardizedFileURL.path
        return pathList.split(separator: ":").contains { item in
            let expandedPath = NSString(string: String(item)).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath).standardizedFileURL.path == targetPath
        }
    }

    private func runStatus() throws {
        let appRunning = PNAppBridge.isPlanetRunning()
        let shouldCheckAPI = options.source == .api || (options.source == .auto && appRunning)
        let client = shouldCheckAPI ? makeAPIClient() : nil
        var apiReachable = false
        if let client {
            apiReachable = client.isReachable()
        }
        if let client, appRunning, !apiReachable {
            try PNAppBridge.openAPIStart(port: client.baseURL.port ?? PNPreferences.apiPort())
            apiReachable = client.waitUntilReachable(seconds: options.timeout)
        }
        let source: String
        if options.source == .disk {
            source = "disk"
        } else if apiReachable {
            source = "api"
        } else {
            source = "disk"
        }
        let status = PNStatus(
            appRunning: appRunning,
            apiReachable: apiReachable,
            source: source,
            apiURL: client?.baseURL.absoluteString ?? options.apiURLOverride?.absoluteString ?? "http://127.0.0.1:8086",
            libraryPath: disk.root.path
        )
        emit(status, human: """
        App running: \(appRunning ? "yes" : "no")
        API reachable: \(apiReachable ? "yes" : "no")
        Source: \(source)
        API URL: \(status.apiURL)
        Library: \(disk.root.path)
        """)
    }

    private func runAPI(arguments input: PNArguments) throws {
        var arguments = input
        guard let subcommand = arguments.pop() else { throw PNError.usage("Missing api command.") }
        switch subcommand {
        case "status":
            try arguments.ensureNoExtras()
            let client = makeAPIClient()
            let state = client.probe()
            let reachable = state != .unreachable
            let authRequired = state == .unauthorized
            let human: String
            if reachable {
                human = "API running at \(client.baseURL.absoluteString)\(authRequired ? " (authentication required)" : "")"
            } else {
                human = "API stopped at \(client.baseURL.absoluteString)"
            }
            emit(PNAPIStatus(reachable: reachable, url: client.baseURL.absoluteString, authRequired: authRequired), human: human)
        case "start":
            let port = Int(try arguments.option("--port") ?? String(PNPreferences.apiPort())) ?? PNPreferences.apiPort()
            let wait = TimeInterval(try arguments.option("--wait") ?? "10") ?? 10
            try arguments.ensureNoExtras()
            try PNAppBridge.openAPIStart(port: port)
            let client = PNAPIClient(baseURL: URL(string: "http://127.0.0.1:\(port)")!, timeout: options.timeout)
            guard client.waitUntilReachable(seconds: wait) else {
                throw PNError.apiUnavailable("Planet API did not become reachable at port \(port).")
            }
            let authRequired = client.probe() == .unauthorized
            emit(
                PNAPIStatus(reachable: true, url: client.baseURL.absoluteString, authRequired: authRequired),
                human: "API running at \(client.baseURL.absoluteString)\(authRequired ? " (authentication required)" : "")"
            )
        case "stop":
            try arguments.ensureNoExtras()
            try PNAppBridge.openAPIStop()
            emit(["stopping": true], human: "API stop requested.")
        default:
            throw PNError.usage("Unknown api command: \(subcommand)")
        }
    }

    private func runLibrary(arguments input: PNArguments) throws {
        var arguments = input
        guard let subcommand = arguments.pop() else { throw PNError.usage("Missing library command.") }
        switch subcommand {
        case "path":
            try arguments.ensureNoExtras()
            emit(["path": disk.root.path], human: disk.root.path)
        case "doctor":
            try arguments.ensureNoExtras()
            let result = try disk.doctor()
            emit(result, human: """
            Library: \(result.libraryPath)
            My planets: \(result.myPlanetsPathExists ? "ok" : "missing")
            Public: \(result.publicPathExists ? "ok" : "missing")
            Templates: \(result.templatesPathExists ? "ok" : "missing")
            Planets: \(result.planetCount)
            Templates: \(result.templateCount)
            """)
        default:
            throw PNError.usage("Unknown library command: \(subcommand)")
        }
    }

    private func runTemplate(arguments input: PNArguments) throws {
        var arguments = input
        guard let subcommand = arguments.pop() else { throw PNError.usage("Missing template command.") }
        switch subcommand {
        case "list":
            try arguments.ensureNoExtras()
            let templates = try disk.templates()
            emit(templates, human: table(headers: ["Name", "Version", "Path"], rows: templates.map { [$0.name, $0.version ?? "", $0.path] }))
        default:
            throw PNError.usage("Unknown template command: \(subcommand)")
        }
    }

    private func runPlanet(arguments input: PNArguments) throws {
        var arguments = input
        guard let subcommand = arguments.pop() else { throw PNError.usage("Missing planet command.") }
        switch subcommand {
        case "list":
            let includeAll = arguments.flag("--all")
            let archived = arguments.flag("--archived")
            try arguments.ensureNoExtras()
            let planets = try selectedPlanets(includeAll: includeAll, archived: archived)
            emit(planets, human: table(headers: ["ID", "Name", "Template", "Updated"], rows: planets.map { [$0.id.uuidString, $0.name, $0.templateName, PNDateParser.format($0.updated)] }))
        case "show":
            let selector = try arguments.require("planet")
            try arguments.ensureNoExtras()
            let planet = try resolvePlanet(selector)
            emit(planet, human: planetDescription(planet))
        case "path":
            let selector = try arguments.require("planet")
            let publicPath = arguments.flag("--public")
            try arguments.ensureNoExtras()
            let planet = try disk.resolvePlanet(selector)
            let path = publicPath ? disk.planetPublicPath(planet).path : disk.planetBasePath(planet).path
            emit(["path": path], human: path)
        case "create":
            let name = try arguments.option("--name")?.pnNilIfEmpty
            guard let name else { throw PNError.usage("planet create requires --name.") }
            let about = try arguments.option("--about") ?? ""
            let template = try arguments.option("--template")
            let avatar = try arguments.option("--avatar").map { URL(fileURLWithPath: $0) }
            try arguments.ensureNoExtras()
            let planet = try createPlanet(name: name, about: about, template: template, avatar: avatar)
            emit(planet, human: planetDescription(planet))
        case "update":
            let selector = try arguments.require("planet")
            let name = try arguments.option("--name")
            let about = try arguments.option("--about")
            let template = try arguments.option("--template")
            let avatar = try arguments.option("--avatar").map { URL(fileURLWithPath: $0) }
            try arguments.ensureNoExtras()
            let planet = try updatePlanet(selector: selector, name: name, about: about, template: template, avatar: avatar)
            emit(planet, human: planetDescription(planet))
        case "delete":
            let selector = try arguments.require("planet")
            let yes = arguments.flag("--yes")
            try arguments.ensureNoExtras()
            try confirm("Delete planet \(selector)?", yes: yes)
            let planet = try deletePlanet(selector: selector)
            emit(planet, human: "Deleted planet \(planet.name) (\(planet.id.uuidString)).")
        case "publish":
            let selector = try arguments.require("planet")
            let wait = arguments.flag("--wait")
            try arguments.ensureNoExtras()
            let planet = try publishPlanet(selector: selector, wait: wait)
            emit(planet, human: "Publish requested for \(planet.name) (\(planet.id.uuidString)).")
        default:
            throw PNError.usage("Unknown planet command: \(subcommand)")
        }
    }

    private func runArticle(arguments input: PNArguments) throws {
        var arguments = input
        guard let subcommand = arguments.pop() else { throw PNError.usage("Missing article command.") }
        switch subcommand {
        case "list":
            let planetSelector = try arguments.require("planet")
            let includeAll = arguments.flag("--all")
            let limit = Int(try arguments.option("--limit") ?? "0") ?? 0
            try arguments.ensureNoExtras()
            let (planet, articles) = try selectedArticles(planetSelector: planetSelector, includeAll: includeAll)
            let shown = limit > 0 ? Array(articles.prefix(limit)) : articles
            emit(shown, human: table(headers: ["ID", "Ref", "Title", "Created"], rows: shown.map { [$0.id.uuidString, $0.reference(in: planet) ?? "", $0.title, PNDateParser.format($0.created)] }))
        case "show":
            let planetSelector = try arguments.require("planet")
            let articleSelector = try arguments.require("article")
            let contentOnly = arguments.flag("--content")
            try arguments.ensureNoExtras()
            let (planet, article) = try resolvePlanetArticle(planetSelector: planetSelector, articleSelector: articleSelector)
            if contentOnly && !options.outputJSON {
                print(article.content)
            } else {
                emit(article, human: articleDescription(article, planet: planet))
            }
        case "path":
            let planetSelector = try arguments.require("planet")
            let articleSelector = try arguments.require("article")
            let publicPath = arguments.flag("--public")
            try arguments.ensureNoExtras()
            let planet = try disk.resolvePlanet(planetSelector)
            let article = try disk.resolveArticle(articleSelector, in: planet)
            let path = publicPath ? disk.articlePublicPath(article, in: planet).path : disk.articlePath(article, in: planet).path
            emit(["path": path], human: path)
        case "create":
            let planetSelector = try arguments.require("planet")
            let title = try arguments.option("--title") ?? ""
            let content = try contentArgument(&arguments)
            let date = try arguments.option("--date").map(PNDateParser.parse)
            let attachments = try arguments.repeatedOption("--attachment").map { URL(fileURLWithPath: $0) }
            try arguments.ensureNoExtras()
            let article = try createArticle(planetSelector: planetSelector, title: title, content: content, date: date, attachments: attachments)
            emit(article, human: "Created article \(article.title) (\(article.id.uuidString)).")
        case "update":
            let planetSelector = try arguments.require("planet")
            let articleSelector = try arguments.require("article")
            let title = try arguments.option("--title")
            let content = try optionalContentArgument(&arguments)
            let date = try arguments.option("--date").map(PNDateParser.parse)
            let replaceAttachments = arguments.flag("--replace-attachments")
            let attachments = try arguments.repeatedOption("--attachment").map { URL(fileURLWithPath: $0) }
            try arguments.ensureNoExtras()
            let article = try updateArticle(
                planetSelector: planetSelector,
                articleSelector: articleSelector,
                title: title,
                content: content,
                date: date,
                replaceAttachments: replaceAttachments,
                attachments: attachments
            )
            emit(article, human: "Updated article \(article.title) (\(article.id.uuidString)).")
        case "delete":
            let planetSelector = try arguments.require("planet")
            let articleSelector = try arguments.require("article")
            let yes = arguments.flag("--yes")
            try arguments.ensureNoExtras()
            try confirm("Delete article \(articleSelector) from \(planetSelector)?", yes: yes)
            let article = try deleteArticle(planetSelector: planetSelector, articleSelector: articleSelector)
            emit(article, human: "Deleted article \(article.title) (\(article.id.uuidString)).")
        case "attachment":
            try runArticleAttachment(arguments: arguments)
        default:
            throw PNError.usage("Unknown article command: \(subcommand)")
        }
    }

    private func runArticleAttachment(arguments input: PNArguments) throws {
        var arguments = input
        guard let subcommand = arguments.pop() else { throw PNError.usage("Missing article attachment command.") }
        switch subcommand {
        case "list":
            let planetSelector = try arguments.require("planet")
            let articleSelector = try arguments.require("article")
            try arguments.ensureNoExtras()
            let names = try articleAttachmentNames(planetSelector: planetSelector, articleSelector: articleSelector)
            emit(["attachments": names], human: names.isEmpty ? "(none)" : names.joined(separator: "\n"))
        case "add":
            let planetSelector = try arguments.require("planet")
            let articleSelector = try arguments.require("article")
            let paths = arguments.popRemaining().map { URL(fileURLWithPath: $0) }
            try arguments.ensureNoExtras()
            guard !paths.isEmpty else {
                throw PNError.usage("article attachment add requires at least one file path.")
            }
            let article = try addArticleAttachments(planetSelector: planetSelector, articleSelector: articleSelector, attachments: paths)
            emit(article, human: "Attachments for \(article.title): \((article.attachments ?? []).joined(separator: ", "))")
        case "delete", "rm":
            let planetSelector = try arguments.require("planet")
            let articleSelector = try arguments.require("article")
            let yes = arguments.flag("--yes")
            let names = arguments.popRemaining()
            try arguments.ensureNoExtras()
            guard !names.isEmpty else {
                throw PNError.usage("article attachment delete requires at least one attachment name.")
            }
            try confirm("Delete \(names.count) attachment(s) from \(articleSelector)?", yes: yes)
            let article = try deleteArticleAttachments(planetSelector: planetSelector, articleSelector: articleSelector, names: names)
            emit(article, human: "Attachments for \(article.title): \((article.attachments ?? []).isEmpty ? "(none)" : (article.attachments ?? []).joined(separator: ", "))")
        default:
            throw PNError.usage("Unknown article attachment command: \(subcommand)")
        }
    }

    private func runSearch(arguments input: PNArguments) throws {
        var arguments = input
        let query = try arguments.require("query")
        let limit = Int(try arguments.option("--limit") ?? "20") ?? 20
        let planetSelector = try arguments.option("--planet")
        try arguments.ensureNoExtras()
        let response: PNSearchResponse
        switch try backend() {
        case .api(let client):
            response = try client.search(query: query, limit: limit)
        case .disk:
            let planet = try planetSelector.map { try disk.resolvePlanet($0) }
            response = try disk.search(query: query, limit: limit, planetFilter: planet)
        }
        let filtered: PNSearchResponse
        if case .api = try backend(), let planetSelector {
            let planet = try resolvePlanet(planetSelector)
            filtered = PNSearchResponse(
                planets: response.planets.filter { $0.id == planet.id },
                articles: response.articles.filter { $0.planetID == planet.id }
            )
        } else {
            filtered = response
        }
        emit(filtered, human: searchDescription(filtered))
    }

    private func backend() throws -> PNBackend {
        switch options.source {
        case .disk:
            return .disk(disk)
        case .api:
            return .api(try ensuredAPIClient())
        case .auto:
            if PNAppBridge.isPlanetRunning() {
                return .api(try ensuredAPIClient())
            }
            return .disk(disk)
        }
    }

    private func makeAPIClient() -> PNAPIClient {
        PNAPIClient(baseURL: PNPreferences.apiURL(override: options.apiURLOverride), timeout: options.timeout)
    }

    private func ensuredAPIClient() throws -> PNAPIClient {
        if let ensuredClient {
            return ensuredClient
        }
        let client = makeAPIClient()
        var state = client.probe()
        if state == .unreachable {
            try PNAppBridge.openAPIStart(port: client.baseURL.port ?? PNPreferences.apiPort())
            guard client.waitUntilReachable(seconds: options.timeout) else {
                throw PNError.apiUnavailable("Planet API is not reachable at \(client.baseURL.absoluteString).")
            }
            state = client.probe()
        }
        if state == .unauthorized {
            try authenticateAPIClient(client)
        }
        ensuredClient = client
        return client
    }

    private func authenticateAPIClient(_ client: PNAPIClient) throws {
        let environment = ProcessInfo.processInfo.environment
        let defaultUsername = environment["PN_API_USERNAME"]?.pnNilIfEmpty ?? "Planet"

        if let passcode = environment["PN_API_PASSCODE"]?.pnNilIfEmpty {
            client.credentials = (defaultUsername, passcode)
            if client.probe() == .ok {
                return
            }
            client.credentials = nil
        }

        guard isatty(STDIN_FILENO) != 0 else {
            throw PNError.apiUnavailable("Planet API requires authentication. Set PN_API_USERNAME and PN_API_PASSCODE, or run pn in an interactive terminal.")
        }

        for _ in 0..<3 {
            let username = promptLine("Username [\(defaultUsername)]: ")?.pnNilIfEmpty ?? defaultUsername
            guard let passcode = promptSecret("Passcode: ")?.pnNilIfEmpty else {
                throw PNError.apiUnavailable("Planet API authentication cancelled.")
            }
            client.credentials = (username, passcode)
            if client.probe() == .ok {
                return
            }
            FileHandle.standardError.write(Data("pn: invalid username or passcode, try again.\n".utf8))
        }
        client.credentials = nil
        throw PNError.apiUnavailable("Planet API authentication failed after 3 attempts.")
    }

    private func promptLine(_ prompt: String) -> String? {
        FileHandle.standardError.write(Data(prompt.utf8))
        return readLine()
    }

    private func promptSecret(_ prompt: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 1024)
        guard let raw = readpassphrase(prompt, &buffer, buffer.count, 0) else {
            return nil
        }
        return String(cString: raw)
    }

    private func selectedPlanets(includeAll: Bool, archived: Bool) throws -> [PNPlanetRecord] {
        switch try backend() {
        case .api(let client):
            return try client.planets(includeArchived: includeAll || archived, archivedOnly: archived)
        case .disk:
            return try disk.planets(includeArchived: includeAll || archived, archivedOnly: archived)
        }
    }

    private func resolvePlanet(_ selector: String) throws -> PNPlanetRecord {
        switch try backend() {
        case .api(let client):
            let planets = try client.planets(includeArchived: true)
            return try resolvePlanet(selector, in: planets)
        case .disk:
            return try disk.resolvePlanet(selector)
        }
    }

    private func resolvePlanet(_ selector: String, in planets: [PNPlanetRecord]) throws -> PNPlanetRecord {
        let matches = PNSelector.planets(planets, matching: selector)
        guard !matches.isEmpty else { throw PNError.notFound("Planet not found: \(selector)") }
        guard matches.count == 1 else {
            throw PNError.ambiguous("Planet selector is ambiguous:\n" + matches.map { "\($0.id.uuidString)  \($0.name)" }.joined(separator: "\n"))
        }
        return matches[0]
    }

    private func selectedArticles(planetSelector: String, includeAll: Bool) throws -> (PNPlanetRecord, [PNArticleRecord]) {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            return (planet, try client.articles(planetID: planet.id))
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            return (planet, try disk.articles(for: planet, includeAll: includeAll))
        }
    }

    private func resolvePlanetArticle(planetSelector: String, articleSelector: String) throws -> (PNPlanetRecord, PNArticleRecord) {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            let article = try resolveArticle(articleSelector, in: try client.articles(planetID: planet.id), planet: planet)
            return (planet, article)
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            return (planet, try disk.resolveArticle(articleSelector, in: planet))
        }
    }

    private func resolveArticle(_ selector: String, in articles: [PNArticleRecord], planet: PNPlanetRecord) throws -> PNArticleRecord {
        let matches = PNSelector.articles(articles, matching: selector, planet: planet)
        guard !matches.isEmpty else { throw PNError.notFound("Article not found: \(selector)") }
        guard matches.count == 1 else {
            throw PNError.ambiguous("Article selector is ambiguous:\n" + matches.map { "\($0.id.uuidString)  \($0.reference(in: planet) ?? "-")  \($0.title)" }.joined(separator: "\n"))
        }
        return matches[0]
    }

    private func createPlanet(name: String, about: String, template: String?, avatar: URL?) throws -> PNPlanetRecord {
        switch try backend() {
        case .api(let client):
            return try client.createPlanet(name: name, about: about, template: template, avatar: avatar)
        case .disk:
            return try disk.createPlanet(name: name, about: about, template: template, avatar: avatar)
        }
    }

    private func updatePlanet(selector: String, name: String?, about: String?, template: String?, avatar: URL?) throws -> PNPlanetRecord {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(selector, in: client.planets(includeArchived: true))
            return try client.updatePlanet(id: planet.id, name: name, about: about, template: template, avatar: avatar)
        case .disk:
            let planet = try disk.resolvePlanet(selector)
            return try disk.updatePlanet(planet, name: name, about: about, template: template, avatar: avatar)
        }
    }

    private func deletePlanet(selector: String) throws -> PNPlanetRecord {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(selector, in: client.planets(includeArchived: true))
            return try client.deletePlanet(id: planet.id)
        case .disk:
            return try disk.deletePlanet(disk.resolvePlanet(selector))
        }
    }

    private func publishPlanet(selector: String, wait: Bool) throws -> PNPlanetRecord {
        let client = try ensuredAPIClient()
        let planet = try resolvePlanet(selector, in: client.planets(includeArchived: true))
        let before = planet.lastPublished
        let published = try client.publishPlanet(id: planet.id)
        guard wait else { return published }
        let deadline = Date().addingTimeInterval(options.timeout)
        while Date() < deadline {
            let current = try client.planet(id: planet.id)
            if current.lastPublished != before {
                return current
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return published
    }

    private func createArticle(planetSelector: String, title: String, content: String, date: Date?, attachments: [URL]) throws -> PNArticleRecord {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            return try client.createArticle(planetID: planet.id, title: title, content: content, date: date, attachments: attachments)
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            return try disk.createArticle(planet: planet, title: title, content: content, date: date, attachments: attachments)
        }
    }

    private func updateArticle(planetSelector: String, articleSelector: String, title: String?, content: String?, date: Date?, replaceAttachments: Bool, attachments: [URL]) throws -> PNArticleRecord {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            let article = try resolveArticle(articleSelector, in: try client.articles(planetID: planet.id), planet: planet)
            return try client.updateArticle(planetID: planet.id, articleID: article.id, title: title, content: content, date: date, replaceAttachments: replaceAttachments, attachments: attachments)
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            let article = try disk.resolveArticle(articleSelector, in: planet)
            return try disk.updateArticle(planet: planet, article: article, title: title, content: content, date: date, replaceAttachments: replaceAttachments, attachments: attachments)
        }
    }

    private func deleteArticle(planetSelector: String, articleSelector: String) throws -> PNArticleRecord {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            let article = try resolveArticle(articleSelector, in: try client.articles(planetID: planet.id), planet: planet)
            return try client.deleteArticle(planetID: planet.id, articleID: article.id)
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            let article = try disk.resolveArticle(articleSelector, in: planet)
            return try disk.deleteArticle(planet: planet, article: article)
        }
    }

    private func articleAttachmentNames(planetSelector: String, articleSelector: String) throws -> [String] {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            let article = try resolveArticle(articleSelector, in: try client.articles(planetID: planet.id), planet: planet)
            return try client.articleAttachments(planetID: planet.id, articleID: article.id)
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            let article = try disk.resolveArticle(articleSelector, in: planet)
            return disk.articleAttachmentNames(for: article)
        }
    }

    private func addArticleAttachments(planetSelector: String, articleSelector: String, attachments: [URL]) throws -> PNArticleRecord {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            let article = try resolveArticle(articleSelector, in: try client.articles(planetID: planet.id), planet: planet)
            return try client.addArticleAttachments(planetID: planet.id, articleID: article.id, attachments: attachments)
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            let article = try disk.resolveArticle(articleSelector, in: planet)
            return try disk.addAttachments(planet: planet, article: article, attachments: attachments)
        }
    }

    private func deleteArticleAttachments(planetSelector: String, articleSelector: String, names: [String]) throws -> PNArticleRecord {
        switch try backend() {
        case .api(let client):
            let planet = try resolvePlanet(planetSelector, in: client.planets(includeArchived: true))
            let article = try resolveArticle(articleSelector, in: try client.articles(planetID: planet.id), planet: planet)
            var updated = article
            for name in names {
                updated = try client.deleteArticleAttachment(planetID: planet.id, articleID: article.id, name: name)
            }
            return updated
        case .disk:
            let planet = try disk.resolvePlanet(planetSelector)
            var article = try disk.resolveArticle(articleSelector, in: planet)
            for name in names {
                article = try disk.deleteAttachment(planet: planet, article: article, name: name)
            }
            return article
        }
    }

    private func contentArgument(_ arguments: inout PNArguments) throws -> String {
        let content = try arguments.option("--content")
        let contentFile = try arguments.option("--content-file")
        guard content == nil || contentFile == nil else {
            throw PNError.usage("Use either --content or --content-file, not both.")
        }
        if let contentFile {
            return try String(contentsOf: URL(fileURLWithPath: contentFile), encoding: .utf8)
        }
        return content ?? ""
    }

    private func optionalContentArgument(_ arguments: inout PNArguments) throws -> String? {
        let content = try arguments.option("--content")
        let contentFile = try arguments.option("--content-file")
        guard content == nil || contentFile == nil else {
            throw PNError.usage("Use either --content or --content-file, not both.")
        }
        if let contentFile {
            return try String(contentsOf: URL(fileURLWithPath: contentFile), encoding: .utf8)
        }
        return content
    }

    private func confirm(_ prompt: String, yes: Bool) throws {
        guard !yes else { return }
        FileHandle.standardError.write(Data("\(prompt) [y/N] ".utf8))
        let answer = readLine()?.pnTrimmed.lowercased()
        guard answer == "y" || answer == "yes" else {
            throw PNError.runtime("Cancelled.")
        }
    }

    private func emit<T: Encodable>(_ value: T, human: String) {
        if options.outputJSON {
            do {
                print(try PNJSON.string(from: value, pretty: options.prettyJSON))
            } catch {
                print("{}")
            }
        } else {
            print(human)
        }
    }

    private func table(headers: [String], rows: [[String]]) -> String {
        guard !rows.isEmpty else {
            return headers.joined(separator: "  ") + "\n" + "(none)"
        }
        let widths = headers.enumerated().map { index, header in
            ([header] + rows.map { index < $0.count ? $0[index] : "" }).map(\.count).max() ?? header.count
        }
        func line(_ values: [String]) -> String {
            values.enumerated().map { index, value in
                value.padding(toLength: widths[index], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
        }
        return ([line(headers), line(widths.map { String(repeating: "-", count: $0) })] + rows.map(line)).joined(separator: "\n")
    }

    private func planetDescription(_ planet: PNPlanetRecord) -> String {
        """
        ID: \(planet.id.uuidString)
        Name: \(planet.name)
        About: \(planet.about)
        Slug: \(planet.slug ?? "")
        Template: \(planet.templateName)
        Updated: \(PNDateParser.format(planet.updated))
        Last Published: \(PNDateParser.format(planet.lastPublished))
        """
    }

    private func articleDescription(_ article: PNArticleRecord, planet: PNPlanetRecord) -> String {
        """
        ID: \(article.id.uuidString)
        Reference: \(article.reference(in: planet) ?? "")
        Title: \(article.title)
        Created: \(PNDateParser.format(article.created))
        Modified: \(PNDateParser.format(article.modified))
        Attachments: \((article.attachments ?? []).joined(separator: ", "))
        """
    }

    private func searchDescription(_ response: PNSearchResponse) -> String {
        let planetRows = response.planets.map { [$0.id.uuidString, $0.name] }
        let articleRows = response.articles.map { [$0.articleID.uuidString, $0.articleReference ?? "", $0.title, $0.planetName] }
        return """
        Planets
        \(table(headers: ["ID", "Name"], rows: planetRows))

        Articles
        \(table(headers: ["ID", "Ref", "Title", "Planet"], rows: articleRows))
        """
    }

    private func helpText(topic: String? = nil) -> String {
        switch topic {
        case "planet":
            return "pn planet list|show|path|create|update|delete|publish ..."
        case "article":
            return "pn article list|show|path|create|update|delete|attachment ..."
        case "api":
            return "pn api status|start|stop"
        default:
            return """
            Usage: pn [--json] [--library <path>] [--api-url <url>] [--source auto|api|disk] <command>

            Commands:
              help [command]
              version
              install [--to ~/.local/bin] [--force]
              status
              api status
              api start [--port 8086] [--wait 10]
              api stop
              library path
              library doctor
              template list
              planet list [--all] [--archived]
              planet show <planet>
              planet path <planet> [--public]
              planet create --name <name> [--about <text>] [--template <name>] [--avatar <path>]
              planet update <planet> [--name <name>] [--about <text>] [--template <name>] [--avatar <path>]
              planet delete <planet> [--yes]
              planet publish <planet> [--wait]
              article list <planet> [--all] [--limit <n>]
              article show <planet> <article> [--content]
              article path <planet> <article> [--public]
              article create <planet> [--title <title>] [--content <text> | --content-file <path>] [--date <iso8601>] [--attachment <path>]...
              article update <planet> <article> [--title <title>] [--content <text> | --content-file <path>] [--date <iso8601>] [--replace-attachments] [--attachment <path>]...
              article delete <planet> <article> [--yes]
              article attachment list <planet> <article>
              article attachment add <planet> <article> <path>...
              article attachment delete <planet> <article> <name>... [--yes]
              search <query> [--limit <n>] [--planet <planet>]
            """
        }
    }
}
