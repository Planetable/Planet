#if DEBUG
import Foundation

/// Debug-build self-test guarding the hand-maintained field lists in
/// `MyPlanetModel.update(from:)` and `MyArticleModel.update(from:)` against
/// drifting from `CodingKeys` when persisted fields are added.
///
/// Strategy: decode a fully-populated fixture (A) and a minimal fixture (B)
/// sharing the same identity, run `B.update(from: A)`, re-encode both, and
/// compare. A field missing from `update(from:)` keeps its default in B and
/// the encoded dictionaries differ. Before that, assert A's encoded output
/// contains every `CodingKeys` case — so adding a key to the model without
/// extending the fixture (and `update(from:)`) fails the check too.
enum ModelUpdateFieldCoverageCheck {
    static func run() {
        do {
            try checkMyPlanetModel()
            try checkMyArticleModel()
            debugPrint("ModelUpdateFieldCoverageCheck passed")
        }
        catch {
            assertionFailure("ModelUpdateFieldCoverageCheck failed: \(error)")
        }
    }

    private enum CheckError: Error, CustomStringConvertible {
        case fixtureMissingKeys(model: String, keys: [String])
        case updateMissedFields(model: String, keys: [String])

        var description: String {
            switch self {
            case .fixtureMissingKeys(let model, let keys):
                return
                    "\(model): full fixture does not cover CodingKeys \(keys) — extend the fixture in ModelUpdateFieldCoverageCheck AND make sure update(from:) copies the new fields"
            case .updateMissedFields(let model, let keys):
                return
                    "\(model): update(from:) does not copy fields \(keys) — keep it in sync with CodingKeys"
            }
        }
    }

    private static func checkMyPlanetModel() throws {
        let id = "11111111-2222-3333-4444-555555555555"
        let full: [String: Any] = [
            "id": id,
            "name": "Full Planet",
            "about": "About text",
            "domain": "example.eth",
            "authorName": "Author",
            "slug": "full-planet",
            "nextArticleNumber": 42,
            "ipns": "k51qzi5uqu5dgv8kzl1anc0m74n6t9ffdjnypdh846ct5wgpljc7rulynxa74a",
            "created": 700000000.0,
            "updated": 700000001.0,
            "templateName": "Plain",
            "lastPublished": 700000002.0,
            "lastPublishedCID": "bafytestcid",
            "archived": true,
            "archivedAt": 700000003.0,
            "plausibleEnabled": true,
            "plausibleDomain": "stats.example.com",
            "plausibleAPIKey": "plausible-key",
            "plausibleAPIServer": "plausible.example.com",
            "twitterUsername": "twitter",
            "githubUsername": "github",
            "telegramUsername": "telegram",
            "mastodonUsername": "mastodon",
            "discordLink": "https://discord.gg/test",
            "dWebServicesEnabled": true,
            "dWebServicesDomain": "dweb.example.com",
            "dWebServicesAPIKey": "dweb-key",
            "pinnableEnabled": true,
            "pinnableAPIEndpoint": "https://pinnable.example.com",
            "pinnablePinCID": "bafypinnable",
            "filebaseEnabled": true,
            "filebasePinName": "pin-name",
            "filebaseAPIToken": "filebase-token",
            "filebaseRequestID": "filebase-request",
            "filebasePinCID": "bafyfilebase",
            "customCodeHeadEnabled": true,
            "customCodeHead": "<meta>",
            "customCodeBodyStartEnabled": true,
            "customCodeBodyStart": "<div>",
            "customCodeBodyEndEnabled": true,
            "customCodeBodyEnd": "</div>",
            "podcastCategories": ["Technology": ["Tech News"]],
            "podcastLanguage": "de",
            "podcastExplicit": true,
            "juiceboxEnabled": true,
            "juiceboxProjectID": 7,
            "juiceboxProjectIDGoerli": 8,
            "acceptsDonation": true,
            "acceptsDonationMessage": "Donate",
            "acceptsDonationETHAddress": "0x0000000000000000000000000000000000000001",
            "tags": ["tag": "Tag"],
            "aggregation": ["https://example.com/feed.xml"],
            "reuseOriginalID": true,
            "saveRoundAvatar": true,
            "doNotIndex": true,
            "prewarmNewPost": false,
            "publishAsIPNS": false,
            "sshRsyncEnabled": true,
            "sshRsyncDestination": "user@host:/var/www/site",
            "sshRsyncKeyPath": "/Users/test/.ssh/id_ed25519",
            "sshRsyncDeleteEnabled": true,
            "cloudflarePagesEnabled": true,
            "cloudflarePagesAccountID": "cf-account",
            "cloudflarePagesAPIToken": "cf-token",
            "cloudflarePagesProjectName": "cf-project",
            "cloudflarePagesLastDeployedProjectName": "cf-project-deployed",
            "cloudflarePagesLastDeployedURL": "https://site.pages.dev",
        ]
        let minimal: [String: Any] = [
            "id": id,
            "name": "Minimal Planet",
            "about": "",
            "ipns": full["ipns"]!,
            "created": full["created"]!,
            "updated": 1.0,
            "templateName": "Croptop",
        ]

        let fullPlanet = try decode(MyPlanetModel.self, from: full)
        let minimalPlanet = try decode(MyPlanetModel.self, from: minimal)
        try assertFixtureCoversAllKeys(
            model: "MyPlanetModel",
            encoded: try encodedDictionary(fullPlanet),
            allKeys: MyPlanetModel.CodingKeys.allCases.map { $0.stringValue },
            exceptions: []
        )

        minimalPlanet.update(from: fullPlanet)
        try assertEncodedEqual(
            model: "MyPlanetModel",
            expected: try encodedDictionary(fullPlanet),
            actual: try encodedDictionary(minimalPlanet)
        )
    }

    private static func checkMyArticleModel() throws {
        let id = "99999999-8888-7777-6666-555555555555"
        let full: [String: Any] = [
            "id": id,
            "articleType": 1,
            "link": "/full-article/",
            "slug": "full-article",
            "articleNumber": 12,
            "heroImage": "hero.png",
            "heroImageWidth": 1200,
            "heroImageHeight": 630,
            "externalLink": "https://example.com/post",
            "title": "Full Article",
            "content": "Full content",
            "contentRendered": "<p>Full content</p>",
            "summary": "Summary",
            "created": 700000000.0,
            "modified": 700000004.0,
            "starred": 700000005.0,
            "starType": 3,
            "videoFilename": "video.mp4",
            "audioFilename": "audio.m4a",
            "attachments": ["video.mp4", "audio.m4a"],
            "cids": ["video.mp4": "bafyvideo"],
            "tags": ["tag": "Tag"],
            "isIncludedInNavigation": true,
            "navigationWeight": 5,
            "originalSiteName": "Origin Site",
            "originalSiteDomain": "origin.example.com",
            "originalPostID": "origin-1",
            "originalPostDate": 700000006.0,
            "pinned": 700000007.0,
        ]
        let minimal: [String: Any] = [
            "id": id,
            "link": "/minimal/",
            "title": "Minimal Article",
            "content": "",
            "created": full["created"]!,
        ]

        let fullArticle = try decode(MyArticleModel.self, from: full)
        let minimalArticle = try decode(MyArticleModel.self, from: minimal)
        try assertFixtureCoversAllKeys(
            model: "MyArticleModel",
            encoded: try encodedDictionary(fullArticle),
            allKeys: MyArticleModel.CodingKeys.allCases.map { $0.stringValue },
            // articleReference is computed from the owning planet (nil here).
            exceptions: ["articleReference"]
        )

        minimalArticle.update(from: fullArticle)
        try assertEncodedEqual(
            model: "MyArticleModel",
            expected: try encodedDictionary(fullArticle),
            actual: try encodedDictionary(minimalArticle)
        )
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder.shared.decode(type, from: data)
    }

    private static func encodedDictionary<T: Encodable>(_ value: T) throws -> NSDictionary {
        let data = try JSONEncoder.shared.encode(value)
        return try JSONSerialization.jsonObject(with: data) as? NSDictionary ?? [:]
    }

    private static func assertFixtureCoversAllKeys(
        model: String,
        encoded: NSDictionary,
        allKeys: [String],
        exceptions: Set<String>
    ) throws {
        let encodedKeys = Set(encoded.allKeys.compactMap { $0 as? String })
        let missing = allKeys.filter { !encodedKeys.contains($0) && !exceptions.contains($0) }
        if !missing.isEmpty {
            throw CheckError.fixtureMissingKeys(model: model, keys: missing.sorted())
        }
    }

    private static func assertEncodedEqual(
        model: String,
        expected: NSDictionary,
        actual: NSDictionary
    ) throws {
        if expected.isEqual(actual) {
            return
        }
        let allKeys = Set(expected.allKeys.compactMap { $0 as? String })
            .union(actual.allKeys.compactMap { $0 as? String })
        let differing = allKeys.filter { key in
            let lhs = expected[key] as? NSObject
            let rhs = actual[key] as? NSObject
            return lhs != rhs
        }
        throw CheckError.updateMissedFields(model: model, keys: differing.sorted())
    }
}
#endif
