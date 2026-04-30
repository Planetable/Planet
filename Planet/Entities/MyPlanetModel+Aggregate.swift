//
//  MyPlanetModel+Aggregate.swift
//  Planet
//
//  Created by Xin Liu on 11/18/23.
//

import Foundation
import SwiftSoup
import SwiftUI

enum AggregationEndpointType: Int, Codable, CaseIterable {
    case ipns = 1
    case ens = 2
    case http = 3
    case unknown = 99
}

private struct AggregateFetchResult {
    var added: Int = 0
    var updated: Int = 0
    var deleted: Int = 0

    var hasChanges: Bool {
        added > 0 || updated > 0 || deleted > 0
    }

    var totalChanges: Int {
        added + updated + deleted
    }

    mutating func formUnion(_ other: AggregateFetchResult) {
        added += other.added
        updated += other.updated
        deleted += other.deleted
    }
}

private struct AggregateAttachmentSyncResult {
    var changedFiles: Int = 0
    var failedAttachments = Set<String>()

    var isComplete: Bool {
        failedAttachments.isEmpty
    }

    var failedAttachmentNames: [String] {
        failedAttachments.sorted()
    }
}

private enum AggregateAttachmentProbePolicy {
    // Keep CID-less validations warm across frequent aggregate runs without pinning them forever.
    static let cidLessValidationTTL: TimeInterval = 6 * 60 * 60
    static let maxConcurrentProbeCount = 4
}

private struct ManagedAttachmentProbeDecision {
    let name: String
    let targetPath: URL
    let attachmentURL: URL
    let shouldDownload: Bool
}

private struct ManagedAttachmentLocalState {
    let byteLength: Int64
    let modificationDate: Date?
}

private actor CIDLessAttachmentValidationCache {
    struct Entry {
        let validatedAt: Date
        let byteLength: Int64
        let modificationDate: Date?
    }

    static let shared = CIDLessAttachmentValidationCache()

    private var entries: [String: Entry] = [:]

    func isFresh(path: String, byteLength: Int64, modificationDate: Date?) -> Bool {
        guard let entry = entries[path] else {
            return false
        }
        guard entry.byteLength == byteLength, entry.modificationDate == modificationDate else {
            entries.removeValue(forKey: path)
            return false
        }
        guard entry.validatedAt > Date().addingTimeInterval(-AggregateAttachmentProbePolicy.cidLessValidationTTL) else {
            entries.removeValue(forKey: path)
            return false
        }
        return true
    }

    func markValidated(path: String, byteLength: Int64, modificationDate: Date?) {
        entries[path] = Entry(
            validatedAt: Date(),
            byteLength: byteLength,
            modificationDate: modificationDate
        )
    }

    func invalidate(path: String) {
        entries.removeValue(forKey: path)
    }
}

/// Aggregate posts from other sites.
extension MyPlanetModel {
    /// Return site type based on its name, then call the appropriate fetch function.
    func determineSiteType(site: String) -> AggregationEndpointType {
        let s = site.lowercased()
        if s.hasPrefix("k51"), s.count == 62 {
            return .ipns
        }
        if s.hasSuffix(".eth"), s.count > 4 {
            return .ens
        }
        if s.hasPrefix("https://") || s.hasPrefix("http://") {
            return .http
        }
        return .unknown
    }

    @ViewBuilder
    func batchDeleteMenu() -> some View {
        if showBatchDeleteMenu() {
            Menu {
                ForEach(getUniqueOriginalSiteDomains(), id: \.self) { domain in
                    Button {
                        Task {
                            await self.batchDeletePosts(domain: domain)
                        }
                    } label: {
                        Text(L10n("Posts from %@", domain))
                            .badge(self.getPostCount(domain: domain))
                    }
                }
            } label: {
                Text("Batch Delete")
            }
        }
    }

    func showBatchDeleteMenu() -> Bool {
        // If any article's originalSiteDomain is not nil, show the menu
        return articles.contains(where: { $0.originalSiteDomain != nil })
    }

    func getUniqueOriginalSiteDomains() -> [String] {
        var domains: [String] = []
        for article in articles {
            if let domain = article.originalSiteDomain, !domains.contains(domain) {
                domains.append(domain)
            }
        }
        return domains
    }

    func getPostCount(domain: String) -> Int {
        var count: Int = 0
        for article in articles {
            if article.originalSiteDomain == domain {
                count += 1
            }
        }
        return count
    }

    func batchDeletePosts(domain: String) async {
        // Delete all articles with the given domain
        let articlesToDelete = articles.filter { $0.originalSiteDomain == domain }
        for article in articlesToDelete {
            article.delete()
        }
        self.tags = self.consolidateTags()
        try? save()
        try? await savePublic()
        Task { @MainActor in
            PlanetStore.shared.refreshSelectedArticles()
        }
    }

    /// Entry function for aggregation.
    ///
    /// Three types of sources are supported:
    /// - IPNS: IPNS name like k51qzi5uqu5di63h1nsegh29khxqvi8rkc59tdq8o5s9b3sftt7rcvr4pdkgo8
    /// - ENS: ENS name like planetable.eth
    /// - HTTP: HTTP URL of RSS feed like https://example.com/feed.xml
    ///
    /// Currently discovering feeds from domains is not supported.
    func aggregate() async {
        if isAggregating {
            debugPrint("Planet \(name) is already aggregating, skipping")
            return
        }
        var finalTaskMessage = L10n("Aggregation completed")
        var finalTaskProgressIndicator: TaskProgressIndicatorType = .done
        var publishMessageTask: Task<Void, Never>?
        await MainActor.run {
            self.isAggregating = true
        }
        let planetName: String = self.name
        DispatchQueue.main.async {
            debugPrint("Aggregation: Started for \(planetName)")
            PlanetStore.shared.currentTaskMessage = L10n("Fetching posts from other sites...")
            PlanetStore.shared.currentTaskProgressIndicator = .progress
            PlanetStore.shared.isAggregating = true
        }
        defer {
            publishMessageTask?.cancel()
            DispatchQueue.main.async {
                debugPrint("Aggregation: Finished for \(planetName)")
                PlanetStore.shared.currentTaskMessage = finalTaskMessage
                PlanetStore.shared.currentTaskProgressIndicator = finalTaskProgressIndicator
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    PlanetStore.shared.isAggregating = false
                }
            }
            Task { @MainActor in
                self.isAggregating = false
            }
        }
        guard let aggregation = aggregation, aggregation.count > 0 else {
            return
        }
        var aggregateResult = AggregateFetchResult()
        for site in aggregation {
            // Skip comments
            if site.hasPrefix("#") || site.hasPrefix("//") {
                continue
            }
            let siteType = determineSiteType(site: site)
            debugPrint("Aggregation: fetching \(site)")
            let siteResult: AggregateFetchResult
            switch siteType {
            case .ipns:
                siteResult = await fetchPlanetSite(site: site)
            case .ens:
                siteResult = await fetchPlanetSite(site: site)
            case .http:
                siteResult = await fetchHTTPSite(site: site)
            case .unknown:
                debugPrint("Site type is unknown: \(site)")
                siteResult = AggregateFetchResult()
            }
            aggregateResult.formUnion(siteResult)
        }
        if aggregateResult.hasChanges {
            let taskMessage = aggregateStatusMessage(for: aggregateResult)
            await MainActor.run {
                updated = Date()
                PlanetStore.shared.currentTaskProgressIndicator = .done
                PlanetStore.shared.currentTaskMessage = taskMessage
            }
            self.tags = self.consolidateTags()
            self.attachmentsLastVerified = nil
            try? save()
            do {
                try await savePublic()
            }
            catch {
                debugPrint("Aggregation: failed to rebuild \(planetName): \(error)")
                finalTaskMessage = L10n("Aggregation failed while rebuilding %@", planetName)
                finalTaskProgressIndicator = .none
                return
            }
            // So the previous message can be seen for a while
            let task = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    PlanetStore.shared.currentTaskProgressIndicator = .progress
                    PlanetStore.shared.currentTaskMessage = L10n("Publishing %@...", planetName)
                }
            }
            publishMessageTask = task
            do {
                try await publish()
            }
            catch {
                debugPrint("Aggregation: failed to publish \(planetName): \(error)")
                finalTaskMessage = L10n("Aggregation failed while publishing %@", planetName)
                finalTaskProgressIndicator = .none
                return
            }
            await MainActor.run {
                PlanetStore.shared.refreshSelectedArticles()
                NotificationCenter.default.post(name: .loadArticle, object: nil)
            }
        }
    }

    private func aggregateStatusMessage(for result: AggregateFetchResult) -> String {
        if result.updated == 0, result.deleted == 0 {
            return L10n("%d new posts fetched", result.added)
        }
        var parts: [String] = []
        if result.added > 0 {
            parts.append(L10n("%d added", result.added))
        }
        if result.updated > 0 {
            parts.append(L10n("%d updated", result.updated))
        }
        if result.deleted > 0 {
            parts.append(L10n("%d deleted", result.deleted))
        }
        if parts.isEmpty {
            return L10n("%d changes applied", result.totalChanges)
        }
        return parts.joined(separator: ", ")
    }

    private func aggregateArticleKey(site: String, originalPostID: String) -> String {
        "\(site)|\(originalPostID)"
    }

    private func aggregatedHeroImageName(from heroImage: String?) -> String? {
        guard let heroImage, !heroImage.isEmpty else {
            return nil
        }
        if heroImage.hasPrefix("https://") || heroImage.hasPrefix("http://") {
            return URL(string: heroImage)?.lastPathComponent
        }
        return heroImage
    }

    private func persistedAttachmentNames(from article: PublicArticleModel) -> [String]? {
        if let articleAttachments = article.attachments, !articleAttachments.isEmpty {
            return articleAttachments
        }
        if let videoFilename = article.videoFilename, !videoFilename.isEmpty {
            return [videoFilename]
        }
        return article.attachments
    }

    private func managedAttachmentNames(from article: PublicArticleModel) -> [String] {
        var names = persistedAttachmentNames(from: article) ?? []
        if let videoFilename = article.videoFilename,
            !videoFilename.isEmpty,
            !names.contains(videoFilename)
        {
            names.append(videoFilename)
        }
        if let audioFilename = article.audioFilename,
            !audioFilename.isEmpty,
            !names.contains(audioFilename)
        {
            names.append(audioFilename)
        }
        if let heroImageName = aggregatedHeroImageName(from: article.heroImage),
            !names.contains(heroImageName)
        {
            names.append(heroImageName)
        }
        return names
    }

    private func currentManagedAttachmentNames(for article: MyArticleModel) -> Set<String> {
        var names = Set(article.attachments ?? [])
        if let videoFilename = article.videoFilename, !videoFilename.isEmpty {
            names.insert(videoFilename)
        }
        if let audioFilename = article.audioFilename, !audioFilename.isEmpty {
            names.insert(audioFilename)
        }
        if let heroImage = article.heroImage, !heroImage.isEmpty {
            names.insert(heroImage)
        }
        return names
    }

    private func managedAttachmentLocalState(at path: URL) -> ManagedAttachmentLocalState? {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path.path)
        let modificationDate = attributes?[.modificationDate] as? Date
        if let fileSize = attributes?[.size] as? NSNumber {
            return ManagedAttachmentLocalState(
                byteLength: fileSize.int64Value,
                modificationDate: modificationDate
            )
        }
        if let fileSize = attributes?[.size] as? Int {
            return ManagedAttachmentLocalState(
                byteLength: Int64(fileSize),
                modificationDate: modificationDate
            )
        }
        return nil
    }

    private func managedAttachmentByteLength(at path: URL) -> Int64? {
        managedAttachmentLocalState(at: path)?.byteLength
    }

    private func hasValidManagedAttachment(at path: URL) -> Bool {
        guard let localState = managedAttachmentLocalState(at: path), localState.byteLength > 0 else {
            return false
        }
        if localState.byteLength < 1000,
            let fileDataString = try? String(contentsOf: path),
            fileDataString.contains("no link named"),
            fileDataString.contains("under")
        {
            return false
        }
        return true
    }

    private func hasCompleteManagedAttachmentCIDCoverage(
        for article: PublicArticleModel,
        expectedAttachmentNames: [String]
    ) -> Bool {
        expectedAttachmentNames.allSatisfy { name in
            guard let remoteCID = article.cids?[name] else {
                return false
            }
            return !remoteCID.isEmpty
        }
    }

    private func fetchRemoteAttachmentByteLength(at url: URL) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                debugPrint(
                    "Aggregation: HEAD request for \(url.absoluteString) returned \(httpResponse.statusCode)"
                )
                return nil
            }
            if httpResponse.expectedContentLength >= 0 {
                return httpResponse.expectedContentLength
            }
            if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                let byteLength = Int64(contentLength)
            {
                return byteLength
            }
        }
        catch {
            debugPrint(
                "Aggregation: failed HEAD request for \(url.absoluteString): \(error)"
            )
        }
        return nil
    }

    private func managedAttachmentMetadataMatches(
        remoteArticle: PublicArticleModel,
        localArticle: MyArticleModel
    ) -> Bool {
        Set(managedAttachmentNames(from: remoteArticle)) == currentManagedAttachmentNames(for: localArticle)
            && localArticle.cids == remoteArticle.cids
    }

    private func managedAttachmentReferencesMatch(
        remoteArticle: PublicArticleModel,
        localArticle: MyArticleModel
    ) -> Bool {
        (persistedAttachmentNames(from: remoteArticle) ?? []) == (localArticle.attachments ?? [])
            && aggregatedHeroImageName(from: remoteArticle.heroImage) == localArticle.heroImage
            && remoteArticle.videoFilename == localArticle.videoFilename
            && remoteArticle.audioFilename == localArticle.audioFilename
            && remoteArticle.cids == localArticle.cids
    }

    private func shouldDownloadManagedAttachment(
        named name: String,
        remoteURL: URL,
        remoteArticle: PublicArticleModel,
        localArticle: MyArticleModel,
        trackedAttachmentSet: Set<String>
    ) async -> Bool {
        let targetPath = localArticle.publicBasePath.appendingPathComponent(
            name,
            isDirectory: false
        )
        guard let localState = managedAttachmentLocalState(at: targetPath),
            localState.byteLength > 0,
            hasValidManagedAttachment(at: targetPath)
        else {
            await CIDLessAttachmentValidationCache.shared.invalidate(path: targetPath.path)
            return true
        }

        if let remoteCID = remoteArticle.cids?[name], !remoteCID.isEmpty {
            if localArticle.cids?[name] == remoteCID {
                return false
            }
            if let localFileCID = try? IPFSDaemon.shared.getFileCIDv0(url: targetPath),
                localFileCID == remoteCID
            {
                return false
            }
            return true
        }

        guard trackedAttachmentSet.contains(name) else {
            await CIDLessAttachmentValidationCache.shared.invalidate(path: targetPath.path)
            return true
        }

        let remotePersistedAttachments = Set(persistedAttachmentNames(from: remoteArticle) ?? [])
        let hasMatchingMetadata =
            remotePersistedAttachments.contains(name) && (localArticle.attachments ?? []).contains(name)
            || (aggregatedHeroImageName(from: remoteArticle.heroImage) == name
                && localArticle.heroImage == name)
            || (remoteArticle.videoFilename == name
                && localArticle.videoFilename == name)
            || (remoteArticle.audioFilename == name
                && localArticle.audioFilename == name)

        guard hasMatchingMetadata else {
            await CIDLessAttachmentValidationCache.shared.invalidate(path: targetPath.path)
            return true
        }

        if await CIDLessAttachmentValidationCache.shared.isFresh(
            path: targetPath.path,
            byteLength: localState.byteLength,
            modificationDate: localState.modificationDate
        ) {
            return false
        }

        if let remoteByteLength = await fetchRemoteAttachmentByteLength(at: remoteURL),
            localState.byteLength == remoteByteLength
        {
            await CIDLessAttachmentValidationCache.shared.markValidated(
                path: targetPath.path,
                byteLength: localState.byteLength,
                modificationDate: localState.modificationDate
            )
            return false
        }

        await CIDLessAttachmentValidationCache.shared.invalidate(path: targetPath.path)
        return true
    }

    private func markCIDLessAttachmentValidated(
        named name: String,
        remoteArticle: PublicArticleModel,
        targetPath: URL
    ) async {
        guard (remoteArticle.cids?[name] ?? "").isEmpty else {
            return
        }
        guard let localState = managedAttachmentLocalState(at: targetPath),
            hasValidManagedAttachment(at: targetPath)
        else {
            await CIDLessAttachmentValidationCache.shared.invalidate(path: targetPath.path)
            return
        }
        await CIDLessAttachmentValidationCache.shared.markValidated(
            path: targetPath.path,
            byteLength: localState.byteLength,
            modificationDate: localState.modificationDate
        )
    }

    private func managedAttachmentProbeDecisionIfPresent(
        named name: String?,
        attachmentBaseURL: URL,
        remoteArticle: PublicArticleModel,
        localArticle: MyArticleModel,
        trackedAttachmentSet: Set<String>
    ) async -> ManagedAttachmentProbeDecision? {
        guard let name else {
            return nil
        }
        let targetPath = localArticle.publicBasePath.appendingPathComponent(
            name,
            isDirectory: false
        )
        let attachmentURL = attachmentBaseURL.appendingPathComponent(name)
        let shouldDownload = await shouldDownloadManagedAttachment(
            named: name,
            remoteURL: attachmentURL,
            remoteArticle: remoteArticle,
            localArticle: localArticle,
            trackedAttachmentSet: trackedAttachmentSet
        )
        return ManagedAttachmentProbeDecision(
            name: name,
            targetPath: targetPath,
            attachmentURL: attachmentURL,
            shouldDownload: shouldDownload
        )
    }

    private func collectManagedAttachmentProbeDecisions(
        expectedAttachmentNames: [String],
        attachmentBaseURL: URL,
        remoteArticle: PublicArticleModel,
        localArticle: MyArticleModel,
        trackedAttachmentSet: Set<String>
    ) async -> [ManagedAttachmentProbeDecision] {
        var decisions: [ManagedAttachmentProbeDecision] = []
        var index = 0
        while index < expectedAttachmentNames.count {
            let upperBound = min(
                index + AggregateAttachmentProbePolicy.maxConcurrentProbeCount,
                expectedAttachmentNames.count
            )
            let names = Array(expectedAttachmentNames[index..<upperBound])
            let name0 = names.indices.contains(0) ? names[0] : nil
            let name1 = names.indices.contains(1) ? names[1] : nil
            let name2 = names.indices.contains(2) ? names[2] : nil
            let name3 = names.indices.contains(3) ? names[3] : nil
            async let decision0 = managedAttachmentProbeDecisionIfPresent(
                named: name0,
                attachmentBaseURL: attachmentBaseURL,
                remoteArticle: remoteArticle,
                localArticle: localArticle,
                trackedAttachmentSet: trackedAttachmentSet
            )
            async let decision1 = managedAttachmentProbeDecisionIfPresent(
                named: name1,
                attachmentBaseURL: attachmentBaseURL,
                remoteArticle: remoteArticle,
                localArticle: localArticle,
                trackedAttachmentSet: trackedAttachmentSet
            )
            async let decision2 = managedAttachmentProbeDecisionIfPresent(
                named: name2,
                attachmentBaseURL: attachmentBaseURL,
                remoteArticle: remoteArticle,
                localArticle: localArticle,
                trackedAttachmentSet: trackedAttachmentSet
            )
            async let decision3 = managedAttachmentProbeDecisionIfPresent(
                named: name3,
                attachmentBaseURL: attachmentBaseURL,
                remoteArticle: remoteArticle,
                localArticle: localArticle,
                trackedAttachmentSet: trackedAttachmentSet
            )
            decisions.append(
                contentsOf: await [decision0, decision1, decision2, decision3].compactMap { $0 }
            )
            index = upperBound
        }
        return decisions
    }

    @discardableResult
    private func updateExistingAggregatedArticle(
        _ existingArticle: MyArticleModel,
        from article: PublicArticleModel,
        site: String,
        siteName: String
    ) async -> Bool {
        let remoteArticleType = article.articleType ?? .blog
        let remoteHeroImageName = aggregatedHeroImageName(from: article.heroImage)
        let remoteAttachments = persistedAttachmentNames(from: article)
        let attachmentSyncResult = await fetchArticleAttachments(
            in: site,
            from: article,
            to: existingArticle,
            strictMode: !managedAttachmentReferencesMatch(
                remoteArticle: article,
                localArticle: existingArticle
            )
        )
        guard attachmentSyncResult.isComplete else {
            debugPrint(
                """
                Aggregation: skipping update for \(article.id.uuidString) from \(site) \
                because managed attachment sync failed: \(attachmentSyncResult.failedAttachmentNames)
                """
            )
            return false
        }
        let metadataChanged = await MainActor.run { () -> Bool in
            var changed = false
            if existingArticle.articleType != remoteArticleType {
                existingArticle.articleType = remoteArticleType
                changed = true
            }
            let localLink = "/\(existingArticle.id.uuidString)/"
            if existingArticle.link != localLink {
                existingArticle.link = localLink
                changed = true
            }
            if existingArticle.externalLink != article.externalLink {
                existingArticle.externalLink = article.externalLink
                changed = true
            }
            if existingArticle.title != article.title {
                existingArticle.title = article.title
                changed = true
            }
            if existingArticle.content != article.content {
                existingArticle.content = article.content
                changed = true
            }
            if existingArticle.created != article.created {
                existingArticle.created = article.created
                changed = true
            }
            if existingArticle.videoFilename != article.videoFilename {
                existingArticle.videoFilename = article.videoFilename
                changed = true
            }
            if existingArticle.audioFilename != article.audioFilename {
                existingArticle.audioFilename = article.audioFilename
                changed = true
            }
            if existingArticle.attachments != remoteAttachments {
                existingArticle.attachments = remoteAttachments
                changed = true
            }
            if existingArticle.heroImage != remoteHeroImageName {
                existingArticle.heroImage = remoteHeroImageName
                existingArticle.heroImageWidth = nil
                existingArticle.heroImageHeight = nil
                changed = true
            }
            if existingArticle.tags != article.tags {
                existingArticle.tags = article.tags
                changed = true
            }
            if existingArticle.cids != article.cids {
                existingArticle.cids = article.cids
                changed = true
            }
            if existingArticle.originalSiteName != siteName {
                existingArticle.originalSiteName = siteName
                changed = true
            }
            if existingArticle.originalSiteDomain != site {
                existingArticle.originalSiteDomain = site
                changed = true
            }
            let originalPostID = article.id.uuidString
            if existingArticle.originalPostID != originalPostID {
                existingArticle.originalPostID = originalPostID
                changed = true
            }
            if existingArticle.originalPostDate != article.created {
                existingArticle.originalPostDate = article.created
                changed = true
            }
            if existingArticle.pinned != article.pinned {
                existingArticle.pinned = article.pinned
                changed = true
            }
            return changed
        }

        return attachmentSyncResult.changedFiles > 0 || metadataChanged
    }

    @discardableResult
    private func fetchArticleAttachments(
        in site: String,
        from article: PublicArticleModel,
        to newArticle: MyArticleModel,
        strictMode: Bool
    ) async -> AggregateAttachmentSyncResult {
        var result = AggregateAttachmentSyncResult()
        var stagedAttachments = [String: URL]()
        let gateway = IPFSState.shared.getGateway()
        let expectedAttachmentNames = managedAttachmentNames(from: article)
        let expectedAttachmentSet = Set(expectedAttachmentNames)
        let trackedAttachmentSet = currentManagedAttachmentNames(for: newArticle)

        if hasCompleteManagedAttachmentCIDCoverage(
            for: article,
            expectedAttachmentNames: expectedAttachmentNames
        ),
            expectedAttachmentSet == trackedAttachmentSet,
            managedAttachmentMetadataMatches(remoteArticle: article, localArticle: newArticle),
            expectedAttachmentNames.allSatisfy({
                hasValidManagedAttachment(
                    at: newArticle.publicBasePath.appendingPathComponent($0, isDirectory: false)
                )
            })
        {
            debugPrint(
                "Aggregation: skipping attachment sync for \(article.id.uuidString), managed files are unchanged"
            )
            return result
        }

        if !expectedAttachmentNames.isEmpty {
            guard let attachmentBaseURL = URL(string: "\(gateway)/ipns/\(site)/\(article.id)/") else {
                for name in expectedAttachmentNames {
                    let targetPath = newArticle.publicBasePath.appendingPathComponent(
                        name,
                        isDirectory: false
                    )
                    if strictMode || !hasValidManagedAttachment(at: targetPath) {
                        result.failedAttachments.insert(name)
                    }
                }
                return result
            }
            debugPrint(
                "Aggregation: \(article.title) has \(expectedAttachmentNames.count) managed files: \(expectedAttachmentNames)"
            )
            let probeDecisions = await collectManagedAttachmentProbeDecisions(
                expectedAttachmentNames: expectedAttachmentNames,
                attachmentBaseURL: attachmentBaseURL,
                remoteArticle: article,
                localArticle: newArticle,
                trackedAttachmentSet: trackedAttachmentSet
            )
            for decision in probeDecisions {
                if !decision.shouldDownload {
                    debugPrint(
                        "Aggregation: skipping attachment \(decision.name), local managed file is up to date"
                    )
                    continue
                }
                debugPrint(
                    "Aggregation: downloading attachment \(decision.attachmentURL.absoluteString)"
                )
                do {
                    let (attachmentData, _) = try await URLSession.shared.data(
                        from: decision.attachmentURL
                    )
                    let existingAttachmentData = try? Data(contentsOf: decision.targetPath)
                    var shouldSave = true
                    if let existingAttachmentData = existingAttachmentData,
                        existingAttachmentData == attachmentData
                    {
                        shouldSave = false
                    }
                    if shouldSave {
                        let stagedAttachmentPath = newArticle.publicBasePath.appendingPathComponent(
                            ".aggregate-\(UUID().uuidString)-\(decision.name)",
                            isDirectory: false
                        )
                        debugPrint(
                            "Aggregation: staging attachment \(decision.name): \(attachmentData.count) bytes"
                        )
                        try attachmentData.write(to: stagedAttachmentPath, options: .atomic)
                        stagedAttachments[decision.name] = stagedAttachmentPath
                    }
                    else {
                        debugPrint(
                            "Aggregation: attachment \(decision.name) is already saved"
                        )
                        await markCIDLessAttachmentValidated(
                            named: decision.name,
                            remoteArticle: article,
                            targetPath: decision.targetPath
                        )
                    }
                }
                catch {
                    debugPrint(
                        "Aggregation: failed to fetch \(decision.name) from \(site): \(error)"
                    )
                    await CIDLessAttachmentValidationCache.shared.invalidate(
                        path: decision.targetPath.path
                    )
                    if strictMode || !hasValidManagedAttachment(at: decision.targetPath) {
                        result.failedAttachments.insert(decision.name)
                    }
                    else {
                        debugPrint(
                            "Aggregation: keeping existing attachment \(decision.name) because the local managed file is still valid"
                        )
                    }
                }
            }
        }

        guard result.isComplete else {
            if !trackedAttachmentSet.subtracting(expectedAttachmentSet).isEmpty {
                debugPrint(
                    """
                    Aggregation: keeping stale attachments for \(article.id.uuidString) \
                    because managed attachment sync is incomplete
                    """
                )
            }
            for stagedAttachmentPath in stagedAttachments.values {
                try? FileManager.default.removeItem(at: stagedAttachmentPath)
            }
            return result
        }

        for (name, stagedAttachmentPath) in stagedAttachments {
            let targetPath = newArticle.publicBasePath.appendingPathComponent(
                name,
                isDirectory: false
            )
            do {
                if FileManager.default.fileExists(atPath: targetPath.path) {
                    _ = try FileManager.default.replaceItemAt(
                        targetPath,
                        withItemAt: stagedAttachmentPath
                    )
                }
                else {
                    try FileManager.default.moveItem(
                        at: stagedAttachmentPath,
                        to: targetPath
                    )
                }
                await markCIDLessAttachmentValidated(
                    named: name,
                    remoteArticle: article,
                    targetPath: targetPath
                )
                result.changedFiles += 1
            }
            catch {
                debugPrint(
                    "Aggregation: failed to commit staged attachment \(name) for \(article.id.uuidString): \(error)"
                )
                try? FileManager.default.removeItem(at: stagedAttachmentPath)
                await CIDLessAttachmentValidationCache.shared.invalidate(path: targetPath.path)
                result.failedAttachments.insert(name)
            }
        }

        guard result.isComplete else {
            if !trackedAttachmentSet.subtracting(expectedAttachmentSet).isEmpty {
                debugPrint(
                    """
                    Aggregation: keeping stale attachments for \(article.id.uuidString) \
                    because staged managed attachment commit failed
                    """
                )
            }
            return result
        }

        for staleAttachment in trackedAttachmentSet.subtracting(expectedAttachmentSet).sorted() {
            let targetPath = newArticle.publicBasePath.appendingPathComponent(
                staleAttachment,
                isDirectory: false
            )
            if FileManager.default.fileExists(atPath: targetPath.path) {
                debugPrint(
                    "Aggregation: removing stale attachment \(staleAttachment)"
                )
                try? FileManager.default.removeItem(at: targetPath)
                await CIDLessAttachmentValidationCache.shared.invalidate(path: targetPath.path)
                result.changedFiles += 1
            }
        }

        return result
    }

    private func fetchPlanetSite(site: String) async -> AggregateFetchResult {
        let gateway = IPFSState.shared.getGateway()
        var result = AggregateFetchResult()
        var newArticles: [MyArticleModel] = []
        if let feedURL = URL(string: "\(gateway)/ipns/\(site)/planet.json") {
            do {
                let (planetJSONData, _) = try await URLSession.shared.data(from: feedURL)
                let planet = try JSONDecoder.shared.decode(
                    PublicPlanetModel.self,
                    from: planetJSONData
                )
                var existingArticlesByOriginalPostID = self.articles.reduce(
                    into: [String: MyArticleModel]()
                ) { partialResult, article in
                    if let originalSiteDomain = article.originalSiteDomain,
                        let originalPostID = article.originalPostID
                    {
                        partialResult[
                            aggregateArticleKey(site: originalSiteDomain, originalPostID: originalPostID)
                        ] = article
                    }
                }
                let remoteArticleIDs = Set(planet.articles.map { $0.id.uuidString })
                debugPrint("Aggregation: fetched \(site) with \(planet.articles.count) articles")
                for article in planet.articles {
                    let articleKey = aggregateArticleKey(
                        site: site,
                        originalPostID: article.id.uuidString
                    )
                    if let existingArticle = existingArticlesByOriginalPostID[articleKey] {
                        let changed = await updateExistingAggregatedArticle(
                            existingArticle,
                            from: article,
                            site: site,
                            siteName: planet.name
                        )
                        if changed {
                            debugPrint("Aggregation: updating \(article.id) from \(site)")
                            try existingArticle.savePublicConcurrently()
                            try existingArticle.save()
                            result.updated += 1
                        }
                    }
                    else {
                        debugPrint("Aggregation: adding \(article.id) from \(site)")
                        let heroImageName = aggregatedHeroImageName(from: article.heroImage)
                        let remoteAttachments = persistedAttachmentNames(from: article)
                        // TODO: Extract summary
                        // TODO: Reuse original ID is dangerous if user do not understand the full implications
                        let postID: UUID
                        if let reuseOriginalID = self.reuseOriginalID, reuseOriginalID == true {
                            postID = article.id
                        }
                        else {
                            postID = UUID()
                        }
                        let newArticle = MyArticleModel(
                            id: postID,
                            link: "/\(postID.uuidString)/",
                            slug: nil,
                            heroImage: nil,
                            externalLink: article.externalLink,
                            title: article.title,
                            content: article.content,
                            summary: "",
                            created: article.created,
                            starred: nil,
                            starType: .star,
                            videoFilename: nil,
                            audioFilename: nil,
                            attachments: []
                        )
                        newArticle.articleType = article.articleType ?? .blog
                        newArticle.tags = article.tags
                        newArticle.originalSiteName = planet.name
                        newArticle.originalSiteDomain = site
                        newArticle.originalPostID = article.id.uuidString
                        newArticle.originalPostDate = article.created
                        newArticle.pinned = article.pinned
                        newArticle.planet = self
                        let publicBasePath = newArticle.publicBasePath
                        if !FileManager.default.fileExists(atPath: publicBasePath.path) {
                            try FileManager.default.createDirectory(
                                at: publicBasePath,
                                withIntermediateDirectories: true
                            )
                        }
                        let attachmentSyncResult = await fetchArticleAttachments(
                            in: site,
                            from: article,
                            to: newArticle,
                            strictMode: true
                        )
                        guard attachmentSyncResult.isComplete else {
                            debugPrint(
                                """
                                Aggregation: skipping new article \(article.id.uuidString) from \(site) \
                                because managed attachment sync failed: \(attachmentSyncResult.failedAttachmentNames)
                                """
                            )
                            newArticle.delete()
                            continue
                        }
                        newArticle.heroImage = heroImageName
                        newArticle.videoFilename = article.videoFilename
                        newArticle.audioFilename = article.audioFilename
                        newArticle.attachments = remoteAttachments
                        newArticle.cids = article.cids
                        try newArticle.save()
                        try newArticle.savePublicConcurrently()
                        newArticles.append(newArticle)
                        existingArticlesByOriginalPostID[articleKey] = newArticle
                        result.added += 1
                    }
                }
                let articlesToDelete = self.articles.filter { article in
                    guard article.originalSiteDomain == site,
                        let originalPostID = article.originalPostID
                    else {
                        return false
                    }
                    return !remoteArticleIDs.contains(originalPostID)
                }
                for article in articlesToDelete {
                    debugPrint("Aggregation: deleting \(article.originalPostID ?? "No Original Post ID") from \(site)")
                    article.delete()
                    result.deleted += 1
                }
                if result.hasChanges {
                    let appendedArticles = newArticles
                    await MainActor.run {
                        if !appendedArticles.isEmpty {
                            articles.append(contentsOf: appendedArticles)
                        }
                        articles.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
                    }
                }
            }
            catch {
                debugPrint("Aggregation: failed to fetch \(site): \(error)")
            }
        }
        return result
    }

    private func fetchHTTPSite(site: String) async -> AggregateFetchResult {
        var result = AggregateFetchResult()
        var newArticles: [MyArticleModel] = []
        guard let feedURL = URL(string: site) else {
            return result
        }
        do {
            let (feedData, _) = try await URLSession.shared.data(from: feedURL)
            let feed = try? await FeedUtils.parseFeed(data: feedData, url: feedURL)
            var existingArticlesByOriginalPostID = self.articles.reduce(
                into: [String: MyArticleModel]()
            ) { partialResult, article in
                if let originalSiteDomain = article.originalSiteDomain,
                    let originalPostID = article.originalPostID
                {
                    partialResult[
                        aggregateArticleKey(site: originalSiteDomain, originalPostID: originalPostID)
                    ] = article
                }
            }
            debugPrint("Aggregation: fetched \(site): \(String(describing: feed))")
            for article in feed?.articles ?? [] {
                if let articleURL = URL(string: article.link) {
                    let articleID = article.link
                    let originalSiteDomain = articleURL.host ?? feedURL.host ?? site
                    let articleKey = aggregateArticleKey(
                        site: originalSiteDomain,
                        originalPostID: articleID
                    )
                    // RSS/Atom aggregation is intentionally append-only.
                    // Many feeds expose only a recent sliding window instead of full history,
                    // so missing items in the feed cannot be treated as deletions or proof of
                    // completeness. Keep previously imported HTTP entries as-is and only append
                    // newly discovered posts from the feed.
                    if existingArticlesByOriginalPostID[articleKey] == nil {
                        debugPrint("Aggregation: adding \(articleID) from \(site)")
                        let newArticleID = UUID()
                        let newArticle = MyArticleModel(
                            id: newArticleID,
                            link: "/\(newArticleID.uuidString)/",
                            slug: nil,
                            heroImage: nil,
                            externalLink: article.link,
                            title: article.title,
                            content: article.content,
                            summary: "",
                            created: article.created,
                            starred: nil,
                            starType: .star,
                            videoFilename: nil,
                            audioFilename: nil,
                            attachments: []
                        )
                        newArticle.tags = [:]
                        newArticle.originalSiteName = feed?.name ?? articleURL.host ?? originalSiteDomain
                        newArticle.originalSiteDomain = originalSiteDomain
                        newArticle.originalPostID = article.link
                        newArticle.originalPostDate = article.created
                        newArticle.planet = self
                        try newArticle.save()
                        let publicBasePath = newArticle.publicBasePath
                        if !FileManager.default.fileExists(atPath: publicBasePath.path) {
                            try FileManager.default.createDirectory(
                                at: publicBasePath,
                                withIntermediateDirectories: true
                            )
                        }
                        let (socialImageData, socialImageName) = await fetchSocialImage(
                            from: articleURL
                        )
                        if let socialImageData = socialImageData,
                            let socialImageName = socialImageName
                        {
                            debugPrint(
                                "Aggregation: saving social image \(socialImageName): \(socialImageData.count) bytes"
                            )
                            let socialImagePath = newArticle.publicBasePath
                                .appendingPathComponent(socialImageName, isDirectory: false)
                            try socialImageData.write(to: socialImagePath)
                            newArticle.heroImage = socialImageName
                            if let size = newArticle.getImageSize(name: socialImageName) {
                                newArticle.heroImageWidth = Int(size.width)
                                newArticle.heroImageHeight = Int(size.height)
                            }
                            newArticle.attachments = [socialImageName]
                            try newArticle.save()
                        }
                        else {
                            debugPrint(
                                "Aggregation: failed to fetch social image from \(articleURL)"
                            )
                        }
                        try newArticle.savePublicConcurrently()
                        newArticles.append(newArticle)
                        existingArticlesByOriginalPostID[articleKey] = newArticle
                        result.added += 1
                    }
                    else {
                        debugPrint("Aggregation: Skipping \(article.link), already saved")
                    }
                }
            }
            if !newArticles.isEmpty {
                let appendedArticles = newArticles
                await MainActor.run {
                    articles.append(contentsOf: appendedArticles)
                    articles.sort(by: { MyArticleModel.reorder(a: $0, b: $1) })
                }
            }
        }
        catch {
            debugPrint("Aggregation: failed to fetch \(site): \(error)")
        }
        return result
    }

    func fetchSocialImage(from url: URL) async -> (data: Data?, name: String?) {
        if url.host?.hasSuffix("youtube.com") ?? false {
            return await fetchYouTubeThumbnail(from: url)
        }
        // Fetch URL, parse it with SwiftSoup, find the first og:image, download it, and return its Data and filename
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(decoding: data, as: UTF8.self)
            let doc: Document = try SwiftSoup.parse(html)
            let ogImage = try doc.select("meta[property=og:image]").first()
            debugPrint("Aggregation: og:image: \(String(describing: ogImage)) found in \(url)")
            if let ogImage = ogImage {
                let ogImageURL = try ogImage.attr("content")
                debugPrint("Aggregation: og:image URL: \(ogImageURL)")
                if let imageURL = URL(string: ogImageURL) {
                    let (ogImageData, _) = try await URLSession.shared.data(from: imageURL)
                    return (ogImageData, imageURL.lastPathComponent)
                }
            }
        }
        catch {
            debugPrint("Failed to fetch social image from \(url): \(error)")
        }
        return (nil, nil)
    }

    func fetchYouTubeThumbnail(from url: URL) async -> (data: Data?, name: String?) {
        // Example URL: https://www.youtube.com/watch?v=YUbD3K9szaI
        // Get the content of v parameter, and fetch https://img.youtube.com/vi/<v>/maxresdefault.jpg
        do {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItem = components.queryItems?.first(where: { $0.name == "v" }),
                let v = queryItem.value
            {
                let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(v)/maxresdefault.jpg")
                if let thumbnailURL = thumbnailURL {
                    let (thumbnailData, _) = try await URLSession.shared.data(from: thumbnailURL)
                    return (thumbnailData, v + "_" + thumbnailURL.lastPathComponent)
                }
            }
        }
        catch {
            debugPrint("Failed to fetch YouTube thumbnail from \(url): \(error)")
        }
        return (nil, nil)
    }
}
