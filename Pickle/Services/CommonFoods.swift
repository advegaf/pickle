import Foundation

/// The bundled, curated starter set. Read directly from JSON in the app bundle (no async DB
/// seed gate) so the very first search a user runs returns clean results instantly, offline.
enum CommonFoods {
    private struct Row: Decodable {
        let name: String
        let kcal: Double
        let p: Double
        let c: Double
        let f: Double
        let serving: Double?
    }

    static let all: [FoodCandidate] = load()

    private static func load() -> [FoodCandidate] {
        guard let url = Bundle.main.url(forResource: "common_foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Row].self, from: data) else {
            return []
        }
        return rows.map { row in
            FoodCandidate(
                name: row.name, brand: nil, source: .common,
                sourceID: row.name.lowercased().replacingOccurrences(of: " ", with: "-"),
                barcode: nil,
                nutrition: FoodNutrition(kcalPer100: row.kcal, proteinPer100: row.p,
                                         carbsPer100: row.c, fatPer100: row.f,
                                         servingGrams: row.serving))
        }
    }

    /// Local matches for a query, ranked. Used as instant results while the network resolves.
    static func search(_ query: String) -> [FoodCandidate] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return FoodRanking.rank(all.filter { $0.name.lowercased().contains(q.lowercased()) }, query: q)
    }

    // MARK: - Curated recommendations (Explore)

    /// A curated, recommended list for an Explore collection. The protein collections rank by
    /// the protein the food actually delivers; the rest are tuned keyword sets, ranked.
    static func recommended(forCollection collection: FoodCollection) -> [FoodCandidate] {
        switch collection.id {
        case "high-protein":
            let proteiny = all.filter { $0.nutrition.proteinPer100 >= 8 }
            return Array(proteiny.sorted { $0.nutrition.proteinPer100 > $1.nutrition.proteinPer100 }.prefix(24))
        case "lean-protein":
            let lean = all.filter { $0.nutrition.proteinPer100 >= 8 && $0.nutrition.fatPer100 <= 10 }
            return Array(lean.sorted { leanScore($0) > leanScore($1) }.prefix(24))
        default:
            let set = collectionKeywords[collection.id] ?? (keywords: [collection.query], excluding: [])
            return ranked(set.keywords, query: collection.query, excluding: set.excluding)
        }
    }

    /// A curated, recommended list for a browse category (a tuned keyword set, ranked).
    static func recommended(forCategory category: FoodCategory) -> [FoodCandidate] {
        let set = categoryKeywords[category] ?? (keywords: [category.query], excluding: [])
        return ranked(set.keywords, query: category.query, excluding: set.excluding)
    }

    // MARK: helpers

    private static func ranked(_ keywords: [String], query: String, excluding: [String]) -> [FoodCandidate] {
        let matches = all.filter { cand in
            let n = cand.name.lowercased()
            guard keywords.contains(where: { n.contains($0) }) else { return false }
            return !excluding.contains(where: { n.contains($0) })
        }
        return Array(FoodRanking.rank(matches, query: query).prefix(24))
    }

    /// Protein delivered per calorie: rewards high-protein, low-energy-density foods.
    private static func leanScore(_ c: FoodCandidate) -> Double {
        c.nutrition.proteinPer100 / max(c.nutrition.kcalPer100, 1)
    }

    private typealias KeywordSet = (keywords: [String], excluding: [String])

    private static let collectionKeywords: [String: KeywordSet] = [
        "breakfast": (["egg", "oat", "yogurt", "granola", "bread", "bagel", "banana", "berr",
                       "cereal", "bacon", "milk", "coffee"], ["almond milk"]),
        "smart-snacks": (["yogurt", "almond", "walnut", "cashew", "peanut", "apple", "banana",
                          "protein bar", "hummus", "cottage cheese", "berr", "carrot",
                          "dark chocolate", "granola"], ["juice", "almond milk"]),
        "whole-grains": (["rice", "quinoa", "oat", "bread", "pasta", "bagel", "cereal"], []),
        "greens": (["broccoli", "spinach", "lettuce", "green bean", "cucumber", "pepper", "salad"], []),
    ]

    private static let categoryKeywords: [FoodCategory: KeywordSet] = [
        .fruit: (["apple", "banana", "orange", "strawberr", "blueberr", "avocado", "grape"],
                 ["juice", "soda"]),
        .vegetables: (["potato", "broccoli", "spinach", "carrot", "tomato", "cucumber", "pepper",
                       "onion", "lettuce", "corn", "green bean"], ["fries", "cereal"]),
        .meat: (["chicken", "beef", "pork", "turkey", "bacon"], []),
        .seafood: (["salmon", "tuna", "shrimp", "fish", "sushi"], []),
        .dairy: (["milk", "cheese", "yogurt", "butter", "cottage", "mozzarella"],
                 ["peanut", "almond"]),
        .grains: (["rice", "bread", "pasta", "oat", "quinoa", "bagel", "cereal", "granola"], []),
        .nuts: (["almond", "peanut", "walnut", "cashew"], ["milk"]),
        .drinks: (["juice", "soda", "cola", "coffee", "beer", "wine", "energy drink"], []),
        .snacks: (["protein bar", "granola", "dark chocolate", "ice cream", "hummus", "almond",
                   "cashew", "walnut"], ["milk"]),
        .fastFood: (["pizza", "burger", "burrito", "sushi", "fries"], []),
    ]
}
