import Foundation

/// One ingredient in a curated recipe: a named food at a fixed gram amount. Macros derive from
/// per-100g nutrition; `candidate` lets it be logged like any food.
struct RecipeItem: Identifiable, Hashable {
    let name: String
    let grams: Double
    let kcalPer100: Double
    let pPer100: Double
    let cPer100: Double
    let fPer100: Double

    var id: String { name }
    var nutrition: FoodNutrition {
        FoodNutrition(kcalPer100: kcalPer100, proteinPer100: pPer100,
                      carbsPer100: cPer100, fatPer100: fPer100, servingGrams: grams)
    }
    var macros: MacroTargets { nutrition.macros(forGrams: grams) }
    var candidate: FoodCandidate {
        FoodCandidate(name: name, brand: nil, source: .common,
                      sourceID: "recipe:\(name.lowercased())", barcode: nil, nutrition: nutrition)
    }
}

/// A curated recipe: a named bundle of ingredients you can log in one tap.
struct Recipe: Identifiable, Hashable {
    let id: String
    let name: String
    let items: [RecipeItem]

    var totals: MacroTargets { items.reduce(.zero) { $0 + $1.macros } }
    /// Background photo asset for the recipe card (`recipe-<id>`); falls back to a gradient.
    var imageAsset: String { "recipe-\(id)" }

    static let all: [Recipe] = [
        Recipe(id: "yogurt-berry-bowl", name: "Greek Yogurt & Berry Bowl", items: [
            RecipeItem(name: "Greek Yogurt", grams: 170, kcalPer100: 59, pPer100: 10, cPer100: 4, fPer100: 0.4),
            RecipeItem(name: "Blueberries", grams: 60, kcalPer100: 57, pPer100: 0.7, cPer100: 14, fPer100: 0.3),
            RecipeItem(name: "Granola", grams: 40, kcalPer100: 471, pPer100: 10, cPer100: 64, fPer100: 20),
        ]),
        Recipe(id: "chicken-rice", name: "Chicken & Rice", items: [
            RecipeItem(name: "Chicken Breast", grams: 150, kcalPer100: 165, pPer100: 31, cPer100: 0, fPer100: 3.6),
            RecipeItem(name: "White Rice", grams: 150, kcalPer100: 130, pPer100: 2.7, cPer100: 28, fPer100: 0.3),
            RecipeItem(name: "Broccoli", grams: 80, kcalPer100: 34, pPer100: 2.8, cPer100: 7, fPer100: 0.4),
        ]),
        Recipe(id: "avocado-toast-eggs", name: "Avocado Toast & Eggs", items: [
            RecipeItem(name: "Whole Wheat Bread", grams: 60, kcalPer100: 247, pPer100: 13, cPer100: 41, fPer100: 3.4),
            RecipeItem(name: "Avocado", grams: 70, kcalPer100: 160, pPer100: 2, cPer100: 9, fPer100: 15),
            RecipeItem(name: "Eggs", grams: 100, kcalPer100: 143, pPer100: 13, cPer100: 0.7, fPer100: 10),
        ]),
        Recipe(id: "salmon-sweet-potato", name: "Salmon & Sweet Potato", items: [
            RecipeItem(name: "Salmon", grams: 150, kcalPer100: 208, pPer100: 20, cPer100: 0, fPer100: 13),
            RecipeItem(name: "Sweet Potato", grams: 150, kcalPer100: 86, pPer100: 1.6, cPer100: 20, fPer100: 0.1),
            RecipeItem(name: "Green Beans", grams: 80, kcalPer100: 31, pPer100: 1.8, cPer100: 7, fPer100: 0.2),
        ]),
        Recipe(id: "oatmeal-banana", name: "Oatmeal, Banana & PB", items: [
            RecipeItem(name: "Oatmeal", grams: 250, kcalPer100: 71, pPer100: 2.5, cPer100: 12, fPer100: 1.5),
            RecipeItem(name: "Banana", grams: 118, kcalPer100: 89, pPer100: 1.1, cPer100: 23, fPer100: 0.3),
            RecipeItem(name: "Peanut Butter", grams: 16, kcalPer100: 588, pPer100: 25, cPer100: 20, fPer100: 50),
        ]),
        Recipe(id: "turkey-quinoa-bowl", name: "Turkey & Quinoa Bowl", items: [
            RecipeItem(name: "Ground Turkey", grams: 150, kcalPer100: 167, pPer100: 20, cPer100: 0, fPer100: 9),
            RecipeItem(name: "Quinoa", grams: 150, kcalPer100: 120, pPer100: 4.4, cPer100: 21, fPer100: 1.9),
            RecipeItem(name: "Spinach", grams: 50, kcalPer100: 23, pPer100: 2.9, cPer100: 3.6, fPer100: 0.4),
        ]),
    ]
}

/// A curated collection that opens as a pre-filtered food search.
struct FoodCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    /// The query the collection seeds the search with.
    let query: String

    static let all: [FoodCollection] = [
        .init(id: "high-protein", title: "High Protein", subtitle: "Anchor your plate", query: "chicken"),
        .init(id: "breakfast", title: "Breakfast", subtitle: "Start strong", query: "egg"),
        .init(id: "smart-snacks", title: "Smart Snacks", subtitle: "Between meals", query: "yogurt"),
        .init(id: "lean-protein", title: "Lean Protein", subtitle: "Low fat, high return", query: "tuna"),
        .init(id: "whole-grains", title: "Whole Grains", subtitle: "Steady energy", query: "rice"),
        .init(id: "greens", title: "Greens", subtitle: "Volume for free", query: "broccoli"),
    ]
}

/// Food categories that seed a search.
enum FoodCategory: String, CaseIterable, Identifiable {
    case fruit = "Fruit"
    case vegetables = "Vegetables"
    case meat = "Meat"
    case seafood = "Seafood"
    case dairy = "Dairy"
    case grains = "Grains"
    case nuts = "Nuts & Seeds"
    case drinks = "Drinks"
    case snacks = "Snacks"
    case fastFood = "Fast Food"

    var id: String { rawValue }

    var query: String {
        switch self {
        case .fruit: return "apple"
        case .vegetables: return "broccoli"
        case .meat: return "chicken"
        case .seafood: return "salmon"
        case .dairy: return "milk"
        case .grains: return "rice"
        case .nuts: return "almonds"
        case .drinks: return "juice"
        case .snacks: return "protein bar"
        case .fastFood: return "burger"
        }
    }
}
