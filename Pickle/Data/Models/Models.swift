import Foundation
import SwiftData

// All models are CloudKit-compatible: every stored property is optional or defaulted,
// no `@Attribute(.unique)`, relationships optional with inverses. Enums persist as raw
// strings. Dedup is handled explicitly by canonicalID + the merge pass, not by a constraint.

@Model
final class UserProfile {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    var name: String = ""
    var sexRaw: String = Sex.male.rawValue
    var age: Int = 30
    var heightCm: Double = 175
    var weightKg: Double = 75

    var activityRaw: String = ActivityLevel.moderate.rawValue
    var goalRaw: String = GoalDirection.maintain.rawValue
    var weeklyRateKg: Double = 0

    var splitProtein: Double = MacroSplit.balanced.protein
    var splitCarbs: Double = MacroSplit.balanced.carbs
    var splitFat: Double = MacroSplit.balanced.fat

    var targetKcal: Int = 2000
    var targetProteinG: Int = 150
    var targetCarbsG: Int = 200
    var targetFatG: Int = 67

    var onboardingComplete: Bool = false
    var planUpdatedAt: Date = Date()

    init() {}

    var sex: Sex { get { Sex(rawValue: sexRaw) ?? .male } set { sexRaw = newValue.rawValue } }
    var activity: ActivityLevel { get { ActivityLevel(rawValue: activityRaw) ?? .moderate } set { activityRaw = newValue.rawValue } }
    var goal: GoalDirection { get { GoalDirection(rawValue: goalRaw) ?? .maintain } set { goalRaw = newValue.rawValue } }
    var split: MacroSplit {
        get { MacroSplit(protein: splitProtein, carbs: splitCarbs, fat: splitFat) }
        set { splitProtein = newValue.protein; splitCarbs = newValue.carbs; splitFat = newValue.fat }
    }
    var targets: MacroTargets {
        MacroTargets(kcal: targetKcal, proteinG: targetProteinG, carbsG: targetCarbsG, fatG: targetFatG)
    }
}

@Model
final class FoodItemEntry {
    /// Stable identity used to pick a deterministic keeper when CloudKit creates twins.
    /// (Not timestamp — CloudKit batches share server timestamps.)
    var uuid: UUID = UUID()
    var canonicalID: String = ""
    var name: String = ""
    var brand: String?
    var sourceRaw: String = FoodSource.custom.rawValue
    var sourceID: String = ""
    var barcode: String?

    var kcalPer100: Double = 0
    var proteinPer100: Double = 0
    var carbsPer100: Double = 0
    var fatPer100: Double = 0
    var servingGrams: Double?

    var isFavorite: Bool = false
    var isCustom: Bool = false
    var createdAt: Date = Date()
    var lastUsedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \LogEntry.food)
    var logs: [LogEntry]? = []

    init() {}

    var source: FoodSource { get { FoodSource(rawValue: sourceRaw) ?? .custom } set { sourceRaw = newValue.rawValue } }
    var nutrition: FoodNutrition {
        FoodNutrition(kcalPer100: kcalPer100, proteinPer100: proteinPer100,
                      carbsPer100: carbsPer100, fatPer100: fatPer100, servingGrams: servingGrams)
    }

    func candidate() -> FoodCandidate {
        FoodCandidate(name: name, brand: brand, source: source, sourceID: sourceID,
                      barcode: barcode, nutrition: nutrition)
    }
}

@Model
final class LogEntry {
    var id: UUID = UUID()
    var loggedAt: Date = Date()
    var localDay: String = ""
    var mealRaw: String = MealSlot.snack.rawValue

    // Denormalized so an entry is self-sufficient even if its food object is merged/deleted.
    var name: String = ""
    var brand: String?
    var canonicalID: String = ""
    var amount: Double = 1
    var unitRaw: String = ServingUnit.serving.rawValue

    var kcal: Int = 0
    var proteinG: Int = 0
    var carbsG: Int = 0
    var fatG: Int = 0

    var food: FoodItemEntry?

    init() {}

    var meal: MealSlot { get { MealSlot(rawValue: mealRaw) ?? .snack } set { mealRaw = newValue.rawValue } }
    var unit: ServingUnit { get { ServingUnit(rawValue: unitRaw) ?? .serving } set { unitRaw = newValue.rawValue } }
    var macros: MacroTargets { MacroTargets(kcal: kcal, proteinG: proteinG, carbsG: carbsG, fatG: fatG) }
}

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var recordedAt: Date = Date()
    var localDay: String = ""
    var weightKg: Double = 0
    var fromHealthKit: Bool = false

    init() {}
}

/// A historical record of a plan target (each onboarding build + each adaptive recalibration).
/// Feeds Coach's "what changed and why" and the adaptive trend.
@Model
final class PlanSnapshot {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var kcal: Int = 0
    var proteinG: Int = 0
    var carbsG: Int = 0
    var fatG: Int = 0
    var reason: String = ""
    var estimatedMaintenanceKcal: Int?

    init() {}
}
