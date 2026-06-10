import AppKit
import XCTest

final class PNDiskStoreTests: XCTestCase {
    func testPlanetCreateAndUpdateAvatarWritesPNGFilesInTemporaryLibrary() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let store = PNDiskStore(root: sandbox.libraryURL)
        let avatar = try sandbox.makeImageFixture(name: "avatar.jpg", width: 300, height: 200)
        let planet = try store.createPlanet(name: "Avatar Test", about: "", template: nil, avatar: avatar)
        defer { _ = try? store.deletePlanet(planet) }

        try assertPNG(at: sandbox.libraryURL.appendingPathComponent("My/\(planet.id.uuidString)/avatar.png"), width: 144, height: 144)
        try assertPNG(at: sandbox.libraryURL.appendingPathComponent("Public/\(planet.id.uuidString)/avatar.png"), width: 144, height: 144)
        try assertPNG(at: sandbox.libraryURL.appendingPathComponent("My/\(planet.id.uuidString)/favicon.ico"), width: 32, height: 32)
        try assertPNG(at: sandbox.libraryURL.appendingPathComponent("Public/\(planet.id.uuidString)/favicon.ico"), width: 32, height: 32)
        var publicPlanet = try readPublicPlanet(in: sandbox.libraryURL, id: planet.id)
        XCTAssertEqual(publicPlanet.id, planet.id)
        XCTAssertEqual(publicPlanet.name, "Avatar Test")
        XCTAssertEqual(publicPlanet.about, "")
        XCTAssertEqual(publicPlanet.ipns, planet.ipns)
        XCTAssertEqual(publicPlanet.articles.count, 0)

        let replacement = try sandbox.makeImageFixture(name: "replacement.png", width: 180, height: 260)
        let updated = try store.updatePlanet(planet, name: "Updated Avatar Test", about: "new about", template: nil, avatar: replacement)
        try assertPNG(at: sandbox.libraryURL.appendingPathComponent("My/\(updated.id.uuidString)/avatar.png"), width: 144, height: 144)
        try assertPNG(at: sandbox.libraryURL.appendingPathComponent("Public/\(updated.id.uuidString)/favicon.ico"), width: 32, height: 32)
        publicPlanet = try readPublicPlanet(in: sandbox.libraryURL, id: updated.id)
        XCTAssertEqual(publicPlanet.name, "Updated Avatar Test")
        XCTAssertEqual(publicPlanet.about, "new about")
    }

    func testArticleLifecycleSearchAndSelectorsStayInsideTemporaryLibrary() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let store = PNDiskStore(root: sandbox.libraryURL)
        let planet = try store.createPlanet(name: "CLI Test Planet", about: "private fixture", template: nil, avatar: nil)
        defer { _ = try? store.deletePlanet(planet) }

        let attachment = try sandbox.makeTextFixture(name: "note.txt", contents: "attachment")
        let article = try store.createArticle(
            planet: planet,
            title: "Launch Notes",
            content: "Planet CLI search target",
            date: PNDateParser.parse("2026-06-09T12:00:00Z"),
            attachments: [attachment]
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.articlePath(article, in: planet).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.articlePublicPath(article, in: planet).appendingPathComponent("article.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.articlePublicPath(article, in: planet).appendingPathComponent("note.txt").path))
        XCTAssertTrue(store.articlePath(article, in: planet).path.hasPrefix(sandbox.libraryURL.path))
        var publicPlanet = try readPublicPlanet(in: sandbox.libraryURL, id: planet.id)
        XCTAssertEqual(publicPlanet.articles.map(\.id), [article.id])
        XCTAssertEqual(publicPlanet.articles.first?.title, "Launch Notes")
        let publicUpdatedAfterCreate = publicPlanet.updated

        let search = try store.search(query: "search target", limit: 10, planetFilter: nil)
        XCTAssertEqual(search.articles.map(\.articleID), [article.id])

        Thread.sleep(forTimeInterval: 0.01)
        let updated = try store.updateArticle(
            planet: planet,
            article: article,
            title: "Updated Launch Notes",
            content: "Updated content",
            date: nil,
            replaceAttachments: false,
            attachments: []
        )
        XCTAssertEqual(updated.title, "Updated Launch Notes")
        publicPlanet = try readPublicPlanet(in: sandbox.libraryURL, id: planet.id)
        XCTAssertEqual(publicPlanet.articles.map(\.id), [updated.id])
        XCTAssertEqual(publicPlanet.articles.first?.title, "Updated Launch Notes")
        XCTAssertEqual(publicPlanet.articles.first?.content, "Updated content")
        XCTAssertGreaterThan(publicPlanet.updated, publicUpdatedAfterCreate)

        _ = try store.deleteArticle(planet: planet, article: updated)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.articlePath(updated, in: planet).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.articlePublicPath(updated, in: planet).path))
        publicPlanet = try readPublicPlanet(in: sandbox.libraryURL, id: planet.id)
        XCTAssertEqual(publicPlanet.articles.count, 0)
    }

    func testPublicPlanetJSONMirrorsAppPublicMetadataFields() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let store = PNDiskStore(root: sandbox.libraryURL)
        let planet = try store.createPlanet(name: "Metadata Test", about: "metadata fixture", template: nil, avatar: nil)
        defer { _ = try? store.deletePlanet(planet) }

        let privatePlanetURL = sandbox.libraryURL
            .appendingPathComponent("My", isDirectory: true)
            .appendingPathComponent(planet.id.uuidString, isDirectory: true)
            .appendingPathComponent("planet.json", isDirectory: false)
        var privatePlanet = try PNJSON.readObject(from: privatePlanetURL)
        privatePlanet["plausibleEnabled"] = true
        privatePlanet["plausibleDomain"] = "stats.example.com"
        privatePlanet["plausibleAPIServer"] = "https://plausible.example.com"
        privatePlanet["juiceboxEnabled"] = true
        privatePlanet["juiceboxProjectID"] = 42
        privatePlanet["juiceboxProjectIDGoerli"] = 43
        privatePlanet["acceptsDonation"] = true
        privatePlanet["acceptsDonationMessage"] = "Thanks for the support"
        privatePlanet["acceptsDonationETHAddress"] = "0x0123456789abcdef"
        privatePlanet["twitterUsername"] = "planet"
        privatePlanet["githubUsername"] = "Planetable"
        privatePlanet["telegramUsername"] = "planet_chat"
        privatePlanet["mastodonUsername"] = "@planet@example.social"
        privatePlanet["discordLink"] = "https://discord.gg/planet"
        privatePlanet["podcastCategories"] = ["Technology": ["News"]]
        privatePlanet["podcastLanguage"] = "en-US"
        privatePlanet["podcastExplicit"] = false
        privatePlanet["tags"] = ["cli": "CLI", "swift": "Swift"]
        try PNJSON.writeObject(privatePlanet, to: privatePlanetURL)

        let refreshedPlanet = try store.resolvePlanet(planet.id.uuidString)
        _ = try store.updatePlanet(refreshedPlanet, name: "Metadata Test Updated", about: nil, template: nil, avatar: nil)

        let publicPlanet = try readPublicPlanet(in: sandbox.libraryURL, id: planet.id)
        XCTAssertEqual(publicPlanet.name, "Metadata Test Updated")
        XCTAssertEqual(publicPlanet.plausibleEnabled, true)
        XCTAssertEqual(publicPlanet.plausibleDomain, "stats.example.com")
        XCTAssertEqual(publicPlanet.plausibleAPIServer, "https://plausible.example.com")
        XCTAssertEqual(publicPlanet.juiceboxEnabled, true)
        XCTAssertEqual(publicPlanet.juiceboxProjectID, 42)
        XCTAssertEqual(publicPlanet.juiceboxProjectIDGoerli, 43)
        XCTAssertEqual(publicPlanet.acceptsDonation, true)
        XCTAssertEqual(publicPlanet.acceptsDonationMessage, "Thanks for the support")
        XCTAssertEqual(publicPlanet.acceptsDonationETHAddress, "0x0123456789abcdef")
        XCTAssertEqual(publicPlanet.twitterUsername, "planet")
        XCTAssertEqual(publicPlanet.githubUsername, "Planetable")
        XCTAssertEqual(publicPlanet.telegramUsername, "planet_chat")
        XCTAssertEqual(publicPlanet.mastodonUsername, "@planet@example.social")
        XCTAssertEqual(publicPlanet.discordLink, "https://discord.gg/planet")
        XCTAssertEqual(publicPlanet.podcastCategories?["Technology"], ["News"])
        XCTAssertEqual(publicPlanet.podcastLanguage, "en-US")
        XCTAssertEqual(publicPlanet.podcastExplicit, false)
        XCTAssertEqual(publicPlanet.tags, ["cli": "CLI", "swift": "Swift"])
    }

    func testAttachmentAppendReplaceClearAndDeleteOne() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let store = PNDiskStore(root: sandbox.libraryURL)
        let planet = try store.createPlanet(name: "Attachment Planet", about: "", template: nil, avatar: nil)
        defer { _ = try? store.deletePlanet(planet) }

        let one = try sandbox.makeTextFixture(name: "one.txt", contents: "one")
        let two = try sandbox.makeTextFixture(name: "two.txt", contents: "two")
        let three = try sandbox.makeTextFixture(name: "three.txt", contents: "three")

        var article = try store.createArticle(planet: planet, title: "A", content: "B", date: nil, attachments: [one])
        XCTAssertEqual(article.attachments, ["one.txt"])

        // Append keeps existing and adds the new one.
        article = try store.addAttachments(planet: planet, article: article, attachments: [two])
        XCTAssertEqual(article.attachments, ["one.txt", "two.txt"])
        XCTAssertEqual(store.articleAttachmentNames(for: article), ["one.txt", "two.txt"])

        // Replace drops all existing and adds only the new set.
        article = try store.updateArticle(planet: planet, article: article, title: nil, content: nil, date: nil, replaceAttachments: true, attachments: [three])
        XCTAssertEqual(article.attachments, ["three.txt"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.articlePublicPath(article, in: planet).appendingPathComponent("one.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.articlePublicPath(article, in: planet).appendingPathComponent("three.txt").path))

        // Delete one by name.
        article = try store.addAttachments(planet: planet, article: article, attachments: [one, two])
        XCTAssertEqual(article.attachments, ["three.txt", "one.txt", "two.txt"])
        article = try store.deleteAttachment(planet: planet, article: article, name: "one.txt")
        XCTAssertEqual(article.attachments, ["three.txt", "two.txt"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.articlePublicPath(article, in: planet).appendingPathComponent("one.txt").path))

        do {
            _ = try store.deleteAttachment(planet: planet, article: article, name: "missing.txt")
            XCTFail("Expected not-found error for unknown attachment.")
        } catch PNError.notFound {
            // expected
        }

        // Replace with an empty set clears all.
        article = try store.updateArticle(planet: planet, article: article, title: nil, content: nil, date: nil, replaceAttachments: true, attachments: [])
        XCTAssertEqual(article.attachments, [])
        let publicArticle = try readPublicPlanet(in: sandbox.libraryURL, id: planet.id).articles.first
        XCTAssertEqual(publicArticle?.attachments, [])
    }

    func testPartialUUIDSelectorsResolveWithExactMatchPrecedence() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let store = PNDiskStore(root: sandbox.libraryURL)
        let now = Date()
        let planetA = PNPlanetRecord(
            id: UUID(uuidString: "AAAA1111-0000-4000-8000-000000000001")!,
            name: "Alpha",
            about: "",
            ipns: "k51-fixture-a",
            created: now,
            updated: now,
            templateName: "Plain"
        )
        let planetB = PNPlanetRecord(
            id: UUID(uuidString: "AAAA2222-0000-4000-8000-000000000002")!,
            name: "AAAA1111",
            about: "",
            ipns: "k51-fixture-b",
            created: now,
            updated: now,
            templateName: "Plain"
        )
        try writePlanetFixture(planetA, in: sandbox.libraryURL)
        try writePlanetFixture(planetB, in: sandbox.libraryURL)

        XCTAssertEqual(try store.resolvePlanet("aaaa1111-0000").id, planetA.id)
        XCTAssertEqual(try store.resolvePlanet(planetA.id.uuidString.lowercased()).id, planetA.id)
        XCTAssertEqual(try store.resolvePlanet("aaaa1111").id, planetB.id, "Exact name match should win over a UUID prefix match.")

        do {
            _ = try store.resolvePlanet("AAAA")
            XCTFail("Expected ambiguous selector error for a shared UUID prefix.")
        } catch PNError.ambiguous(let message) {
            XCTAssertTrue(message.contains(planetA.id.uuidString))
            XCTAssertTrue(message.contains(planetB.id.uuidString))
        }

        let article = PNArticleRecord(
            id: UUID(uuidString: "BBBB3333-0000-4000-8000-000000000003")!,
            link: "/BBBB3333-0000-4000-8000-000000000003/",
            title: "Hello",
            content: "World",
            created: now
        )
        try writeArticleFixture(article, planet: planetA, in: sandbox.libraryURL)
        XCTAssertEqual(try store.resolveArticle("bbbb3333", in: planetA).id, article.id)
        XCTAssertEqual(try store.resolveArticle("hello", in: planetA).id, article.id)
    }

    func testAmbiguousSelectorsFailWithCandidateIDs() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let store = PNDiskStore(root: sandbox.libraryURL)
        let first = try store.createPlanet(name: "Same Name", about: "", template: nil, avatar: nil)
        let second = try store.createPlanet(name: "Same Name", about: "", template: nil, avatar: nil)
        defer {
            _ = try? store.deletePlanet(first)
            _ = try? store.deletePlanet(second)
        }

        do {
            _ = try store.resolvePlanet("same name")
            XCTFail("Expected ambiguous selector error.")
        } catch PNError.ambiguous(let message) {
            XCTAssertTrue(message.contains(first.id.uuidString))
            XCTAssertTrue(message.contains(second.id.uuidString))
        } catch {
            XCTFail("Expected PNError.ambiguous, got \(error).")
        }
    }

    func testPreferencesResolveLibraryAndIPFSPathsFromTestEnvironment() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let external = sandbox.root.appendingPathComponent("External", isDirectory: true)
        let externalPlanet = external.appendingPathComponent("Planet", isDirectory: true)
        try FileManager.default.createDirectory(at: externalPlanet, withIntermediateDirectories: true)

        let preferencesDirectory = sandbox.containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: preferencesDirectory, withIntermediateDirectories: true)
        let preferences: [String: Any] = [PNPreferences.settingsLibraryLocation: external.path]
        let data = try PropertyListSerialization.data(fromPropertyList: preferences, format: .xml, options: 0)
        try data.write(to: PNPreferences.preferencesURL, options: .atomic)

        XCTAssertEqual(PNPreferences.libraryURL(override: nil).path, externalPlanet.standardizedFileURL.path)
        XCTAssertEqual(PNPreferences.ipfsRepositoryURL.path, sandbox.ipfsRepositoryURL.path)
        XCTAssertEqual(PNPreferences.ipfsExecutableOverrideURL?.path, sandbox.fakeIPFSURL.path)
    }

    func testGlobalOptionParserSupportsHermeticDiskInvocation() throws {
        let sandbox = try PNTestSandbox()
        defer { sandbox.cleanup() }

        let parsed = try PNCommandRunner.parseGlobalOptions([
            "--json",
            "--library", sandbox.libraryURL.path,
            "--source", "disk",
            "planet", "list"
        ])

        XCTAssertTrue(parsed.options.outputJSON)
        XCTAssertEqual(parsed.options.source, .disk)
        XCTAssertEqual(parsed.options.libraryOverride?.standardizedFileURL.path, sandbox.libraryURL.path)
        XCTAssertEqual(parsed.arguments, ["planet", "list"])
    }

    private func writePlanetFixture(_ planet: PNPlanetRecord, in libraryURL: URL) throws {
        let directory = libraryURL
            .appendingPathComponent("My", isDirectory: true)
            .appendingPathComponent(planet.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try PNJSON.write(planet, to: directory.appendingPathComponent("planet.json", isDirectory: false))
    }

    private func writeArticleFixture(_ article: PNArticleRecord, planet: PNPlanetRecord, in libraryURL: URL) throws {
        let directory = libraryURL
            .appendingPathComponent("My", isDirectory: true)
            .appendingPathComponent(planet.id.uuidString, isDirectory: true)
            .appendingPathComponent("Articles", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try PNJSON.write(article, to: directory.appendingPathComponent("\(article.id.uuidString).json", isDirectory: false))
    }

    private func assertPNG(at url: URL, width: Int, height: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10], file: file, line: line)
        guard let image = NSBitmapImageRep(data: data) else {
            return XCTFail("Expected image data at \(url.path)", file: file, line: line)
        }
        XCTAssertEqual(image.pixelsWide, width, file: file, line: line)
        XCTAssertEqual(image.pixelsHigh, height, file: file, line: line)
    }

    private func readPublicPlanet(in libraryURL: URL, id: UUID) throws -> PNPublicPlanetRecord {
        let url = libraryURL
            .appendingPathComponent("Public", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
            .appendingPathComponent("planet.json", isDirectory: false)
        return try PNJSON.read(PNPublicPlanetRecord.self, from: url)
    }
}

private final class PNTestSandbox {
    let root: URL
    let containerURL: URL
    let libraryURL: URL
    let ipfsRepositoryURL: URL
    let fakeIPFSURL: URL
    private let previousContainer: String?
    private let previousIPFSRepository: String?
    private let previousIPFSExecutable: String?

    init() throws {
        previousContainer = Self.getenvString(PNPreferences.environmentContainerDataPath)
        previousIPFSRepository = Self.getenvString(PNPreferences.environmentIPFSRepositoryPath)
        previousIPFSExecutable = Self.getenvString(PNPreferences.environmentIPFSExecutablePath)

        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pn-tests-\(UUID().uuidString)", isDirectory: true)
        containerURL = root.appendingPathComponent("Container", isDirectory: true)
        libraryURL = root.appendingPathComponent("Library", isDirectory: true)
        ipfsRepositoryURL = root.appendingPathComponent("IPFS", isDirectory: true)
        fakeIPFSURL = root.appendingPathComponent("fake-ipfs", isDirectory: false)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ipfsRepositoryURL, withIntermediateDirectories: true)
        try writeFakeIPFS()

        setenv(PNPreferences.environmentContainerDataPath, containerURL.path, 1)
        setenv(PNPreferences.environmentIPFSRepositoryPath, ipfsRepositoryURL.path, 1)
        setenv(PNPreferences.environmentIPFSExecutablePath, fakeIPFSURL.path, 1)
    }

    func cleanup() {
        restore(PNPreferences.environmentContainerDataPath, previousContainer)
        restore(PNPreferences.environmentIPFSRepositoryPath, previousIPFSRepository)
        restore(PNPreferences.environmentIPFSExecutablePath, previousIPFSExecutable)
        try? FileManager.default.removeItem(at: root)
    }

    func makeTextFixture(name: String, contents: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: false)
        try Data(contents.utf8).write(to: url, options: .atomic)
        return url
    }

    func makeImageFixture(name: String, width: Int, height: Int) throws -> URL {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSColor.systemBlue.setFill()
        NSRect(x: width / 3, y: height / 3, width: width / 3, height: height / 3).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            throw PNError.diskError("Unable to create image fixture.")
        }
        let type: NSBitmapImageRep.FileType = name.lowercased().hasSuffix(".jpg") || name.lowercased().hasSuffix(".jpeg") ? .jpeg : .png
        guard let data = bitmap.representation(using: type, properties: [:]) else {
            throw PNError.diskError("Unable to encode image fixture.")
        }
        let url = root.appendingPathComponent(name, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func writeFakeIPFS() throws {
        let script = """
        #!/bin/sh
        set -eu
        mkdir -p "${IPFS_PATH}"
        if [ "$1" = "init" ]; then
          echo "{}" > "${IPFS_PATH}/config"
          echo "initialized"
          exit 0
        fi
        if [ "$1" = "key" ] && [ "$2" = "gen" ]; then
          echo "k51qzi-test-$5"
          exit 0
        fi
        if [ "$1" = "key" ] && [ "$2" = "rm" ]; then
          exit 0
        fi
        echo "unsupported fake ipfs command: $*" >&2
        exit 1
        """
        try Data(script.utf8).write(to: fakeIPFSURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeIPFSURL.path)
    }

    private static func getenvString(_ name: String) -> String? {
        guard let value = getenv(name) else { return nil }
        return String(validatingUTF8: value)
    }

    private func restore(_ name: String, _ value: String?) {
        if let value {
            setenv(name, value, 1)
        } else {
            unsetenv(name)
        }
    }
}
