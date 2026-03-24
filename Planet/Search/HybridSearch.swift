//
//  HybridSearch.swift
//  Planet
//
//  Created by Claude on 3/24/26.
//

import Foundation

enum HybridSearch {
    /// Reciprocal Rank Fusion constant. Higher values flatten rank differences.
    private static let k: Double = 60

    /// Weight multiplier for BM25 (keyword) results — precision signal.
    private static let bm25Weight: Double = 1.5

    /// Weight multiplier for vector (semantic) results — recall signal.
    private static let vectorWeight: Double = 1.0

    /// Fuse BM25 and vector search results using Reciprocal Rank Fusion.
    ///
    /// Each result list contributes `weight / (k + rank)` to a shared score per article.
    /// Articles appearing in both lists get the sum of their contributions.
    /// Final results are sorted by descending fused score.
    static func fuse(
        bm25Results: [SearchResult],
        vectorResults: [SearchResult],
        limit: Int = 200
    ) -> [SearchResult] {
        var scores: [UUID: Double] = [:]
        var bm25Scores: [UUID: Double] = [:]
        var vectorScores: [UUID: Double] = [:]
        var bestResult: [UUID: SearchResult] = [:]

        // Score BM25 results
        for (rank, result) in bm25Results.enumerated() {
            let score = bm25Weight / (k + Double(rank + 1))
            scores[result.articleID, default: 0] += score
            bm25Scores[result.articleID] = score
            bestResult[result.articleID] = result
        }

        // Score vector results
        for (rank, result) in vectorResults.enumerated() {
            let score = vectorWeight / (k + Double(rank + 1))
            scores[result.articleID, default: 0] += score
            vectorScores[result.articleID] = score
            // Keep the result with the better preview (prefer BM25's keyword-aware snippet)
            if bestResult[result.articleID] == nil {
                bestResult[result.articleID] = result
            }
        }

        // Build fused results with combined scores
        var fused: [SearchResult] = scores.compactMap { articleID, score in
            guard let result = bestResult[articleID] else { return nil }
            return SearchResult(
                articleID: result.articleID,
                articleCreated: result.articleCreated,
                title: result.title,
                preview: result.preview,
                planetID: result.planetID,
                planetName: result.planetName,
                planetKind: result.planetKind,
                relevanceScore: score,
                bm25Score: bm25Scores[articleID],
                vectorScore: vectorScores[articleID]
            )
        }

        fused.sort { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }

        if fused.count > limit {
            fused.removeSubrange(limit...)
        }

        return fused
    }
}
