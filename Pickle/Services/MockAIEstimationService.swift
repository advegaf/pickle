import Foundation

/// A believable stand-in for the real vision/text model so the AI flow works end-to-end
/// before the proxy exists. Matches words against the common-foods set; falls back to a
/// plausible composed plate. Deliberately injects one lower-confidence item so the
/// review/sanity UI is exercised.
struct MockAIEstimationService: AIEstimating {
    func estimate(text: String) async throws -> [AIFoodItem] {
        try await Task.sleep(for: .milliseconds(900))
        let lower = text.lowercased()
        guard !lower.trimmingCharacters(in: .whitespaces).isEmpty else { throw AIEstimationError.couldNotRead }

        var items: [AIFoodItem] = []
        for food in CommonFoods.all {
            if lower.contains(food.name.lowercased()) {
                let grams = food.nutrition.servingGrams ?? 100
                items.append(AIFoodItem(name: food.name, portion: "1 serving",
                                        macros: food.nutrition.macros(forGrams: grams),
                                        confidence: 0.85))
            }
            if items.count >= 4 { break }
        }

        if items.isEmpty {
            items = composedPlate(hint: text)
        }
        return items
    }

    func estimate(imageJPEG: Data) async throws -> [AIFoodItem] {
        try await Task.sleep(for: .milliseconds(1200))
        return composedPlate(hint: "photo")
    }

    private func composedPlate(hint: String) -> [AIFoodItem] {
        [
            AIFoodItem(name: "Grilled chicken", portion: "~5 oz",
                       macros: MacroTargets(kcal: 230, proteinG: 43, carbsG: 0, fatG: 5), confidence: 0.82),
            AIFoodItem(name: "White rice", portion: "~1 cup",
                       macros: MacroTargets(kcal: 205, proteinG: 4, carbsG: 45, fatG: 0), confidence: 0.78),
            AIFoodItem(name: "Mixed vegetables", portion: "~1 cup",
                       macros: MacroTargets(kcal: 90, proteinG: 4, carbsG: 18, fatG: 1), confidence: 0.5),
        ]
    }
}
