import Foundation

/// Where a food came from. Drives ranking priority and the canonical dedup key.
enum FoodSource: String, Codable, Sendable {
    case common   // bundled curated starter set
    case custom   // user-created
    case recent   // previously logged
    case off      // Open Food Facts
    case usda     // USDA FoodData Central
}

/// Nutrition normalized to per-100g, plus an optional known serving size in grams.
/// Every source (OFF, USDA, custom, common) maps into this single shape.
struct FoodNutrition: Equatable, Sendable, Codable, Hashable {
    var kcalPer100: Double
    var proteinPer100: Double
    var carbsPer100: Double
    var fatPer100: Double
    /// Grams in one labelled "serving", when the source provides it (OFF serving_quantity).
    var servingGrams: Double?

    /// Usable means: finite, non-negative energy, and not an all-zero ghost entry.
    var isUsable: Bool {
        let fields = [kcalPer100, proteinPer100, carbsPer100, fatPer100]
        guard fields.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return false }
        guard kcalPer100 > 0 else { return false }
        return true
    }

    /// Macros for a given mass in grams.
    func macros(forGrams grams: Double) -> MacroTargets {
        let k = grams / 100.0
        return MacroTargets(
            kcal: Int((kcalPer100 * k).rounded()),
            proteinG: Int((proteinPer100 * k).rounded()),
            carbsG: Int((carbsPer100 * k).rounded()),
            fatG: Int((fatPer100 * k).rounded())
        )
    }
}

/// A search result before it becomes a logged entry. Identified by source+id; deduped by
/// `canonicalID` (barcode when present).
struct FoodCandidate: Identifiable, Equatable, Sendable, Hashable {
    var name: String
    var brand: String?
    var source: FoodSource
    var sourceID: String
    var barcode: String?
    var nutrition: FoodNutrition

    var id: String { "\(source.rawValue):\(sourceID)" }

    /// Stable identity across devices/sources. Barcode is globally unique; otherwise the
    /// source-qualified id. Used to dedup recents/favorites and to merge CloudKit twins.
    var canonicalID: String {
        if let barcode, !barcode.isEmpty { return "barcode:\(barcode)" }
        return id
    }

    var displayDetail: String {
        // Energy for one labelled serving when known, else per 100 g. (The stored values are
        // per-100 g, so showing kcalPer100 under a "serving" label was wrong, e.g. an egg read
        // 143 cal/serving when one ~50 g egg is ~72.)
        let grams = nutrition.servingGrams
        let kcal = nutrition.macros(forGrams: grams ?? 100).kcal
        let per = grams != nil ? "serving" : "100g"
        if let brand, !brand.isEmpty { return "\(brand)   \(kcal) cal/\(per)" }
        return "\(kcal) cal/\(per)"
    }
}
