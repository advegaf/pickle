import Foundation
import SwiftData

/// A user-saved combination of foods, captured from a meal section, that can be re-logged in
/// one tap. Items are denormalized snapshots so the meal survives even if a source food is
/// later deleted. Local-only (CloudKit is off); a simple additive SwiftData model.
@Model
final class LovedMeal {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    // Optional with an explicit inverse so the schema is CloudKit-compatible (CloudKit requires
    // every relationship to be optional and to have an inverse), matching the other models.
    @Relationship(deleteRule: .cascade, inverse: \LovedMealItem.lovedMeal)
    var items: [LovedMealItem]? = []
    init() {}
}

@Model
final class LovedMealItem {
    var foodCanonicalID: String = ""
    var name: String = ""
    var amount: Double = 1
    var unitRaw: String = ServingUnit.serving.rawValue
    var kcal: Int = 0
    var proteinG: Int = 0
    var carbsG: Int = 0
    var fatG: Int = 0
    /// Inverse of `LovedMeal.items` (required for CloudKit compatibility).
    var lovedMeal: LovedMeal?
    init() {}

    var unit: ServingUnit {
        get { ServingUnit(rawValue: unitRaw) ?? .serving }
        set { unitRaw = newValue.rawValue }
    }
    var macros: MacroTargets { MacroTargets(kcal: kcal, proteinG: proteinG, carbsG: carbsG, fatG: fatG) }
}

/// Value-type snapshot of a loved meal for the UI.
struct LovedMealDTO: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let itemCount: Int
    let totals: MacroTargets

    @MainActor init(_ m: LovedMeal) {
        id = m.id
        name = m.name
        let items = m.items ?? []
        itemCount = items.count
        totals = items.reduce(.zero) { $0 + $1.macros }
    }
}
