import Foundation

/// What the Home predicted-meal card shows for the next unlogged slot today.
struct MealPrediction: Equatable {
    let slot: MealSlot
    /// The predicted food. Nil means no history exists for this slot (the card renders
    /// as a "log your first meal" nudge instead of hiding, so the slot teaches itself).
    let food: PredictedFood?

    struct PredictedFood: Equatable {
        let canonicalID: String
        let name: String
        let kcal: Int
        /// Median historical log time for the chosen food, minutes since local midnight.
        let minutesSinceMidnight: Int
    }
}

/// A deterministic, fully local heuristic: what does this user usually log for the next
/// unlogged meal slot? No AI call, no randomness, injectable calendar. Tiers:
/// 1. the most frequent food at that slot over the window (requires >= 3 occurrences),
/// 2. otherwise the most recently logged food at that slot,
/// 3. otherwise (no slot history) a nudge with no food.
enum PredictedMealEngine {

    static func predict(history: [DiaryDay], today: DiaryDay,
                        calendar: Calendar = .current) -> MealPrediction? {
        // The first slot (in meal order) with nothing logged today.
        guard let slot = MealSlot.allCases.first(where: { today.entries(for: $0).isEmpty }) else {
            return nil // every slot logged: nothing left to predict
        }

        let slotEntries = history.flatMap { $0.entries(for: slot) }
        guard !slotEntries.isEmpty else { return MealPrediction(slot: slot, food: nil) }

        // Tier 1: frequency winner. Ties break by most recent, then canonicalID so the
        // result is stable regardless of dictionary ordering.
        let groups = Dictionary(grouping: slotEntries, by: \.canonicalID).values.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            let ra = a.map(\.loggedAt).max() ?? .distantPast
            let rb = b.map(\.loggedAt).max() ?? .distantPast
            if ra != rb { return ra > rb }
            return (a.first?.canonicalID ?? "") < (b.first?.canonicalID ?? "")
        }

        let chosen: [LoggedFood]
        if let winner = groups.first, winner.count >= 3 {
            chosen = winner
        } else if let latest = slotEntries.max(by: { $0.loggedAt < $1.loggedAt }) {
            // Tier 2: whatever was logged at this slot most recently.
            chosen = [latest]
        } else {
            return MealPrediction(slot: slot, food: nil)
        }

        // The most recent occurrence carries the name/kcal (portions drift over time).
        let sample = chosen.max(by: { $0.loggedAt < $1.loggedAt })!
        return MealPrediction(slot: slot, food: .init(
            canonicalID: sample.canonicalID,
            name: sample.name,
            kcal: sample.macros.kcal,
            minutesSinceMidnight: medianMinutes(of: chosen, calendar: calendar)
        ))
    }

    /// Median time-of-day (minutes since local midnight) across entries.
    static func medianMinutes(of entries: [LoggedFood], calendar: Calendar = .current) -> Int {
        let minutes = entries.map { e -> Int in
            let c = calendar.dateComponents([.hour, .minute], from: e.loggedAt)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }.sorted()
        guard !minutes.isEmpty else { return 8 * 60 }
        return minutes[minutes.count / 2]
    }
}
