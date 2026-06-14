import Foundation

/// Ranks, dedups, and sanity-filters merged search results from OFF/USDA/custom/common.
/// The premium feel lives in this list, so it's pure and unit-tested against messy input.
enum FoodRanking {

    /// Drop entries whose nutrition is unusable (no energy, NaN, all-zero ghosts).
    static func sanitize(_ candidates: [FoodCandidate]) -> [FoodCandidate] {
        candidates.filter { $0.nutrition.isUsable }
    }

    /// Remove duplicates by `canonicalID`, keeping the highest-priority source for each
    /// (common > custom > recent > off > usda), then the more complete entry.
    static func dedup(_ candidates: [FoodCandidate]) -> [FoodCandidate] {
        var best: [String: FoodCandidate] = [:]
        var order: [String] = []
        for c in candidates {
            if let existing = best[c.canonicalID] {
                if preferred(c, over: existing) { best[c.canonicalID] = c }
            } else {
                best[c.canonicalID] = c
                order.append(c.canonicalID)
            }
        }
        return order.compactMap { best[$0] }
    }

    /// Full pipeline: sanitize → dedup → rank by relevance to `query`.
    static func rank(_ candidates: [FoodCandidate], query: String) -> [FoodCandidate] {
        let cleaned = dedup(sanitize(candidates))
        let q = normalize(query)
        // Stable, deterministic ordering: score desc, then name asc, then id asc.
        return cleaned.enumerated()
            .sorted { a, b in
                let sa = score(a.element, query: q), sb = score(b.element, query: q)
                if sa != sb { return sa > sb }
                let na = a.element.name.lowercased(), nb = b.element.name.lowercased()
                if na != nb { return na < nb }
                return a.element.id < b.element.id
            }
            .map(\.element)
    }

    // MARK: - Scoring

    static func score(_ c: FoodCandidate, query: String) -> Int {
        let q = normalize(query)
        let name = normalize(c.name)
        var s = 0
        if !q.isEmpty {
            if name == q { s += 100 }
            else if name.hasPrefix(q) { s += 50 }
            else if name.contains(q) { s += 20 }
            if let brand = c.brand, normalize(brand).contains(q) { s += 10 }
        }
        if c.nutrition.servingGrams != nil { s += 5 }   // a known serving is friendlier
        s += sourcePriority(c.source)
        return s
    }

    static func sourcePriority(_ source: FoodSource) -> Int {
        switch source {
        case .common: return 8
        case .custom: return 6
        case .recent: return 7
        case .off: return 3
        case .usda: return 2
        }
    }

    private static func preferred(_ a: FoodCandidate, over b: FoodCandidate) -> Bool {
        let pa = sourcePriority(a.source), pb = sourcePriority(b.source)
        if pa != pb { return pa > pb }
        // Tie on source: prefer the one with a known serving size.
        return (a.nutrition.servingGrams != nil) && (b.nutrition.servingGrams == nil)
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
