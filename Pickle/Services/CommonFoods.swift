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
}
