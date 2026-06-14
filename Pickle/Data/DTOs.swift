import Foundation

// Value-type snapshots that repositories hand to views. SwiftData @Model objects are not
// Sendable and must not cross actors, so everything the UI sees is one of these.

struct LoggedFood: Identifiable, Equatable, Sendable {
    let id: UUID
    let loggedAt: Date
    let localDay: String
    let meal: MealSlot
    let name: String
    let brand: String?
    let canonicalID: String
    let amount: Double
    let unit: ServingUnit
    let macros: MacroTargets
}

struct SavedFood: Identifiable, Equatable, Sendable {
    let canonicalID: String
    let name: String
    let brand: String?
    let source: FoodSource
    let isFavorite: Bool
    let isCustom: Bool
    let nutrition: FoodNutrition
    var id: String { canonicalID }

    func candidate() -> FoodCandidate {
        FoodCandidate(name: name, brand: brand, source: source,
                      sourceID: canonicalID, barcode: nil, nutrition: nutrition)
    }
}

/// One day's diary, aggregated.
struct DiaryDay: Equatable, Sendable {
    let localDay: String
    let entries: [LoggedFood]

    var totals: MacroTargets {
        entries.reduce(.zero) { $0 + $1.macros }
    }

    func entries(for meal: MealSlot) -> [LoggedFood] {
        entries.filter { $0.meal == meal }
    }

    func kcal(for meal: MealSlot) -> Int {
        entries(for: meal).reduce(0) { $0 + $1.macros.kcal }
    }

    var loggedMealCount: Int {
        Set(entries.map(\.meal)).count
    }

    var isEmpty: Bool { entries.isEmpty }
}

extension LoggedFood {
    init(_ e: LogEntry) {
        self.init(id: e.id, loggedAt: e.loggedAt, localDay: e.localDay, meal: e.meal,
                  name: e.name, brand: e.brand, canonicalID: e.canonicalID,
                  amount: e.amount, unit: e.unit, macros: e.macros)
    }
}

extension SavedFood {
    init(_ f: FoodItemEntry) {
        self.init(canonicalID: f.canonicalID, name: f.name, brand: f.brand, source: f.source,
                  isFavorite: f.isFavorite, isCustom: f.isCustom, nutrition: f.nutrition)
    }
}
