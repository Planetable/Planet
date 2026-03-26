//
//  PlanetStore+Spotlight.swift
//  Planet
//
//  Created by Claude on 3/25/26.
//

import AppKit
import CoreSpotlight
import Foundation
import os
import UniformTypeIdentifiers

private let spotlightContentDescriptionMaxLength = 300
private let spotlightIndexBatchSize = 100
private let spotlightBuildVersion = 1
private let spotlightBuildVersionKey = "PlanetSpotlightBuildVersion"
private let spotlightLogger = os.Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Planet",
    category: "Spotlight"
)
private let spotlightLogURL: URL = {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return dir.appendingPathComponent("planet.log")
}()

private func spotlightLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] [Spotlight] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: spotlightLogURL.path) {
            if let handle = try? FileHandle(forWritingTo: spotlightLogURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: spotlightLogURL)
        }
    }
}

// MARK: - Reindex Delegate

final class SpotlightIndexDelegate: NSObject, CSSearchableIndexDelegate {
    func searchableIndex(
        _ searchableIndex: CSSearchableIndex,
        reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void
    ) {
        spotlightLog("System requested full reindex")
        Task { @MainActor in
            _ = await PlanetStore.shared.rebuildSpotlightIndex(
                reason: "system requested full reindex"
            )
            acknowledgementHandler()
        }
    }

    func searchableIndex(
        _ searchableIndex: CSSearchableIndex,
        reindexSearchableItemsWithIdentifiers identifiers: [String],
        acknowledgementHandler: @escaping () -> Void
    ) {
        spotlightLog(
            "System requested reindex for \(identifiers.count) item(s): \(identifiers.joined(separator: ", "))"
        )
        Task { @MainActor in
            let store = PlanetStore.shared
            let snapshots = identifiers.compactMap { idString -> SearchArticleSnapshot? in
                guard let uuid = UUID(uuidString: idString) else {
                    return nil
                }
                return store.cachedSearchSnapshots.first(where: { $0.articleID == uuid })
            }

            do {
                for batchStart in stride(from: 0, to: snapshots.count, by: spotlightIndexBatchSize) {
                    let batchEnd = min(batchStart + spotlightIndexBatchSize, snapshots.count)
                    let items = snapshots[batchStart..<batchEnd].map(
                        PlanetStore.searchableSpotlightItem(for:)
                    )
                    try await PlanetStore.indexSpotlightItems(items)
                }
                spotlightLog("System reindex complete for \(snapshots.count) item(s)")
            } catch {
                spotlightLog("System reindex failed: \(error.localizedDescription)")
                spotlightLogger.error("System reindex failed: \(error.localizedDescription)")
            }

            acknowledgementHandler()
        }
    }
}

extension PlanetStore {

    private static let spotlightDelegate = SpotlightIndexDelegate()

    fileprivate nonisolated static func searchableSpotlightItem(
        for snapshot: SearchArticleSnapshot
    ) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = snapshot.title
        attributeSet.displayName = snapshot.title
        attributeSet.subject = snapshot.planetName
        attributeSet.contentCreationDate = snapshot.articleCreated

        let description: String
        if let preview = snapshot.previewText, !preview.isEmpty {
            description = preview
        } else {
            description = snapshot.content
        }

        if description.count > spotlightContentDescriptionMaxLength {
            attributeSet.contentDescription = String(
                description.prefix(spotlightContentDescriptionMaxLength)
            )
        } else {
            attributeSet.contentDescription = description
        }

        attributeSet.textContent = snapshot.content

        if !snapshot.tags.isEmpty {
            attributeSet.keywords = snapshot.tags
        }

        return CSSearchableItem(
            uniqueIdentifier: snapshot.articleID.uuidString,
            domainIdentifier: snapshot.planetID.uuidString,
            attributeSet: attributeSet
        )
    }

    private nonisolated static func storedSpotlightBuildVersion() -> Int? {
        if let value = UserDefaults.standard.object(forKey: spotlightBuildVersionKey) as? NSNumber {
            return value.intValue
        }
        return UserDefaults.standard.object(forKey: spotlightBuildVersionKey) as? Int
    }

    private nonisolated static func persistSpotlightBuildVersion() {
        UserDefaults.standard.set(spotlightBuildVersion, forKey: spotlightBuildVersionKey)
    }

    private nonisolated static func deleteAllSpotlightItems() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            CSSearchableIndex.default().deleteAllSearchableItems { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    fileprivate nonisolated static func indexSpotlightItems(_ items: [CSSearchableItem]) async throws {
        guard !items.isEmpty else {
            return
        }
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func currentSpotlightSnapshots(forPlanetID planetID: UUID) -> [SearchArticleSnapshot] {
        if let myPlanet = myPlanets.first(where: { $0.id == planetID }) {
            return myPlanet.articles.map(SearchArticleSnapshot.init(article:))
        }
        if let followingPlanet = followingPlanets.first(where: { $0.id == planetID }) {
            return followingPlanet.articles.map(SearchArticleSnapshot.init(article:))
        }
        return cachedSearchSnapshots.filter { $0.planetID == planetID }
    }

    func ensureSpotlightIndexReadyOnLaunch() {
        CSSearchableIndex.default().indexDelegate = Self.spotlightDelegate

        if !spotlightLaunchMarkerLogged {
            spotlightLaunchMarkerLogged = true
            spotlightLog("Launch marker pid=\(ProcessInfo.processInfo.processIdentifier)")
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let articleCount = cachedSearchSnapshots.count
        let storedVersion = Self.storedSpotlightBuildVersion()
        if storedVersion == spotlightBuildVersion {
            spotlightLog(
                "Startup Spotlight sync skipped for pid=\(pid): build version \(spotlightBuildVersion) already applied (\(articleCount) articles)"
            )
            return
        }

        if spotlightRebuildTask != nil {
            spotlightLog(
                "Startup Spotlight sync already in progress for pid=\(pid) (\(articleCount) articles)"
            )
            return
        }

        let storedVersionDescription = storedVersion.map(String.init) ?? "none"
        spotlightLog(
            "Startup Spotlight sync requires full rebuild for pid=\(pid): stored version \(storedVersionDescription), current version \(spotlightBuildVersion), \(articleCount) articles"
        )
        Task { @MainActor in
            _ = await self.rebuildSpotlightIndex(reason: "startup bootstrap")
        }
    }

    // MARK: - Index / Remove Individual Items

    nonisolated static func upsertSpotlightItem(for snapshot: SearchArticleSnapshot) {
        let item = searchableSpotlightItem(for: snapshot)

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                spotlightLog("Failed to index article \(snapshot.articleID): \(error.localizedDescription)")
                spotlightLogger.error(
                    "Failed to index article \(snapshot.articleID): \(error.localizedDescription)"
                )
            } else {
                spotlightLog("Indexed article: \(snapshot.title) (\(snapshot.articleID))")
            }
        }
    }

    nonisolated static func removeSpotlightItem(articleID: UUID) {
        spotlightLog("Removing article \(articleID) from Spotlight")
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [articleID.uuidString]) {
            error in
            if let error {
                spotlightLog("Failed to remove article \(articleID): \(error.localizedDescription)")
                spotlightLogger.error(
                    "Failed to remove article \(articleID) from Spotlight: \(error.localizedDescription)"
                )
            } else {
                spotlightLog("Removed article \(articleID)")
            }
        }
    }

    nonisolated static func removeSpotlightItems(forPlanetID planetID: UUID) {
        spotlightLog("Removing all articles for planet \(planetID) from Spotlight")
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [planetID.uuidString]) {
            error in
            if let error {
                spotlightLog("Failed to remove planet \(planetID) articles: \(error.localizedDescription)")
                spotlightLogger.error(
                    "Failed to remove planet \(planetID) articles from Spotlight: \(error.localizedDescription)"
                )
            } else {
                spotlightLog("Removed all articles for planet \(planetID)")
            }
        }
    }

    // MARK: - Full Rebuild

    func rebuildSpotlightIndex(reason: String = "manual repair") async -> Bool {
        CSSearchableIndex.default().indexDelegate = Self.spotlightDelegate
        if let existingTask = spotlightRebuildTask {
            spotlightLog("Rebuild already in progress; joining existing task for \(reason)")
            return await existingTask.value
        }

        let snapshots = cachedSearchSnapshots
        spotlightLog("Rebuild started (\(reason)) with \(snapshots.count) articles")
        let task = Task.detached(priority: .utility) { [snapshots] in
            do {
                try await Self.deleteAllSpotlightItems()
                spotlightLog("Cleared existing Spotlight index")
            } catch {
                spotlightLog("Failed to clear Spotlight index: \(error.localizedDescription)")
                spotlightLogger.error("Failed to clear Spotlight index: \(error.localizedDescription)")
                return false
            }

            for batchStart in stride(from: 0, to: snapshots.count, by: spotlightIndexBatchSize) {
                let batchEnd = min(batchStart + spotlightIndexBatchSize, snapshots.count)
                let items = snapshots[batchStart..<batchEnd].map(Self.searchableSpotlightItem(for:))
                do {
                    try await Self.indexSpotlightItems(items)
                    spotlightLog(
                        "Indexed batch \(batchStart/spotlightIndexBatchSize + 1) (\(items.count) items)"
                    )
                } catch {
                    spotlightLog(
                        "Failed to index batch \(batchStart/spotlightIndexBatchSize + 1): \(error.localizedDescription)"
                    )
                    spotlightLogger.error(
                        "Failed to batch-index Spotlight items: \(error.localizedDescription)"
                    )
                    return false
                }
            }

            spotlightLog("Rebuild complete: \(snapshots.count) articles indexed")
            spotlightLogger.info("Spotlight index rebuilt with \(snapshots.count) articles")
            return true
        }

        spotlightRebuildTask = task
        let success = await task.value
        spotlightRebuildTask = nil
        if success {
            Self.persistSpotlightBuildVersion()
            spotlightLog("Stored Spotlight build version \(spotlightBuildVersion)")
        }
        return success
    }

    func reindexSpotlightItems(forPlanetID planetID: UUID) async -> Bool {
        CSSearchableIndex.default().indexDelegate = Self.spotlightDelegate

        if let existingTask = spotlightRebuildTask {
            spotlightLog("Planet Spotlight reindex waiting for full rebuild for planet \(planetID)")
            _ = await existingTask.value
        }

        let snapshots = currentSpotlightSnapshots(forPlanetID: planetID)
        replaceSearchSnapshots(forPlanetID: planetID, with: snapshots)

        spotlightLog(
            "Planet Spotlight reindex started for planet \(planetID) with \(snapshots.count) articles"
        )
        guard !snapshots.isEmpty else {
            spotlightLog("Planet Spotlight reindex complete for planet \(planetID) with 0 articles")
            return true
        }

        for batchStart in stride(from: 0, to: snapshots.count, by: spotlightIndexBatchSize) {
            let batchEnd = min(batchStart + spotlightIndexBatchSize, snapshots.count)
            let items = snapshots[batchStart..<batchEnd].map(Self.searchableSpotlightItem(for:))
            do {
                try await Self.indexSpotlightItems(items)
            } catch {
                spotlightLog(
                    "Planet Spotlight reindex failed for planet \(planetID) batch \(batchStart/spotlightIndexBatchSize + 1): \(error.localizedDescription)"
                )
                spotlightLogger.error(
                    "Planet Spotlight reindex failed for planet \(planetID): \(error.localizedDescription)"
                )
                return false
            }
        }

        spotlightLog(
            "Planet Spotlight reindex complete for planet \(planetID) with \(snapshots.count) articles"
        )
        return true
    }

    // MARK: - Handle Spotlight Result Tap

    @MainActor
    static func handleSpotlightActivity(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let articleIDString = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let articleID = UUID(uuidString: articleIDString)
        else {
            return false
        }

        spotlightLog("Spotlight result tapped: article \(articleID)")
        let store = PlanetStore.shared

        // Search in My Planets
        for planet in store.myPlanets {
            if let article = planet.articles.first(where: { $0.id == articleID }) {
                spotlightLog("Navigating to My article: \(article.title) in planet \(planet.name)")
                store.selectedView = .myPlanet(planet)
                NotificationCenter.default.post(
                    name: .scrollToSidebarItem,
                    object: "sidebar-my-\(planet.id.uuidString)"
                )
                Task { @MainActor in
                    await restoreSpotlightSelection(
                        articleID: articleID,
                        planetID: planet.id,
                        isMyPlanet: true,
                        fallbackArticle: article
                    )
                }
                NSApplication.shared.activate(ignoringOtherApps: true)
                return true
            }
        }

        // Search in Following Planets
        for planet in store.followingPlanets {
            if let article = planet.articles.first(where: { $0.id == articleID }) {
                spotlightLog(
                    "Navigating to Following article: \(article.title) in planet \(planet.name)"
                )
                store.selectedView = .followingPlanet(planet)
                NotificationCenter.default.post(
                    name: .scrollToSidebarItem,
                    object: "sidebar-following-\(planet.id.uuidString)"
                )
                Task { @MainActor in
                    await restoreSpotlightSelection(
                        articleID: articleID,
                        planetID: planet.id,
                        isMyPlanet: false,
                        fallbackArticle: article
                    )
                }
                NSApplication.shared.activate(ignoringOtherApps: true)
                return true
            }
        }

        spotlightLog("Article \(articleID) not found in any planet")
        return false
    }

    /// Retry setting selectedArticle until the article list has refreshed after changing selectedView.
    /// Mirrors the retry pattern in SearchView.restoreSelectionAndScroll().
    @MainActor
    private static func restoreSpotlightSelection(
        articleID: UUID,
        planetID: UUID,
        isMyPlanet: Bool,
        fallbackArticle: ArticleModel
    ) async {
        let store = PlanetStore.shared
        let retryDelays: [UInt64] = [80_000_000, 180_000_000, 320_000_000]

        for delay in retryDelays {
            try? await Task.sleep(nanoseconds: delay)

            if isMyPlanet {
                guard case .myPlanet(let selectedPlanet) = store.selectedView,
                      selectedPlanet.id == planetID
                else { continue }
            } else {
                guard case .followingPlanet(let selectedPlanet) = store.selectedView,
                      selectedPlanet.id == planetID
                else { continue }
            }

            if let article = store.selectedArticleList?.first(where: { $0.id == articleID }) {
                store.selectedArticle = article
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
                try? await Task.sleep(nanoseconds: 120_000_000)
                NotificationCenter.default.post(name: .scrollToArticle, object: article)
                return
            }
        }

        store.selectedArticle = fallbackArticle
        NotificationCenter.default.post(name: .scrollToArticle, object: fallbackArticle)
        try? await Task.sleep(nanoseconds: 120_000_000)
        NotificationCenter.default.post(name: .scrollToArticle, object: fallbackArticle)
    }
}
