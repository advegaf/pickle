import Foundation
import SwiftData

/// Collapses CloudKit-created twins. NSPersistentCloudKitContainer has no unique
/// constraints, so two offline devices each create a same-`canonicalID` `FoodItemEntry`
/// and both survive sync. This pass keeps the deterministically-lowest UUID, re-points every
/// `LogEntry` to the keeper, merges flags, and deletes the losers. Runs on remote change.
enum DedupMerger {
    @MainActor
    @discardableResult
    static func merge(in context: ModelContext) -> Int {
        let foods = (try? context.fetch(FetchDescriptor<FoodItemEntry>())) ?? []
        let groups = Dictionary(grouping: foods, by: { $0.canonicalID })
        var mergedCount = 0

        for (cid, twins) in groups where twins.count > 1 && !cid.isEmpty {
            // Deterministic keeper: lowest UUID string (NOT timestamp, CloudKit batches
            // share server timestamps, so timestamps don't break ties reliably).
            let sorted = twins.sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            let keeper = sorted[0]

            for loser in sorted.dropFirst() {
                keeper.isFavorite = keeper.isFavorite || loser.isFavorite
                keeper.isCustom = keeper.isCustom || loser.isCustom
                if let loserUsed = loser.lastUsedAt {
                    keeper.lastUsedAt = max(keeper.lastUsedAt ?? .distantPast, loserUsed)
                }
                // Re-point every log on the loser to the keeper so no LogEntry is orphaned.
                for log in loser.logs ?? [] {
                    log.food = keeper
                }
                context.delete(loser)
                mergedCount += 1
            }
        }

        if mergedCount > 0 { try? context.save() }
        return mergedCount
    }
}

extension PickleStore {
    /// Called when CloudKit pushes a change from another device: merge any new twins,
    /// refresh the widget, and nudge the UI to re-read.
    func handleRemoteChange() {
        DedupMerger.merge(in: context)
        refreshWidgetSnapshot()
        bumpExternal()
    }
}
