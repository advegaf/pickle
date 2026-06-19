import Foundation

/// Converts portion amounts between units and computes macros for a chosen portion.
/// Conversion is only valid within a physical dimension (mass↔mass, volume↔volume).
/// Across dimensions it needs a food-specific bridge (grams-per-serving); without one it
/// refuses rather than guessing, a wrong guess silently corrupts every downstream macro.
enum ServingConverter {

    /// Convert `amount` of `from` into `to`, within the same dimension. nil across
    /// dimensions or for count units (serving/piece) which have no universal factor.
    static func convert(_ amount: Double, from: ServingUnit, to: ServingUnit) -> Double? {
        guard from.dimension == to.dimension else { return nil }
        guard let f = from.toBase, let t = to.toBase, t != 0 else { return nil }
        return amount * f / t
    }

    /// Resolve a chosen portion to grams, so per-100g nutrition can be scaled.
    /// - mass units convert directly.
    /// - volume converts to ml, then needs `gramsPerServing`-style density to reach grams;
    ///   without density we cannot produce grams → nil.
    /// - serving/piece require `gramsPerServing` from the food.
    static func grams(amount: Double, unit: ServingUnit, gramsPerServing: Double?) -> Double? {
        switch unit.dimension {
        case .mass:
            return convert(amount, from: unit, to: .gram)
        case .count:
            guard let g = gramsPerServing, g > 0 else { return nil }
            return amount * g
        case .volume:
            // Volume → grams needs density. If the food declares a serving in grams AND the
            // unit is the canonical serving volume we'd still be guessing, so refuse.
            return nil
        }
    }

    /// Macros for a chosen portion of a food, or nil if the portion can't be resolved to grams.
    static func macros(_ nutrition: FoodNutrition, amount: Double, unit: ServingUnit) -> MacroTargets? {
        guard let g = grams(amount: amount, unit: unit, gramsPerServing: nutrition.servingGrams) else {
            return nil
        }
        return nutrition.macros(forGrams: g)
    }
}
