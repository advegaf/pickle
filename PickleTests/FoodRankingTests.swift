import XCTest
@testable import Pickle

final class FoodRankingTests: XCTestCase {

    private func candidate(_ name: String, source: FoodSource = .off, kcal: Double = 100,
                           barcode: String? = nil, serving: Double? = nil, brand: String? = nil,
                           id: String = UUID().uuidString) -> FoodCandidate {
        FoodCandidate(name: name, brand: brand, source: source, sourceID: id, barcode: barcode,
                      nutrition: FoodNutrition(kcalPer100: kcal, proteinPer100: 5, carbsPer100: 10,
                                               fatPer100: 2, servingGrams: serving))
    }

    func testSanitize_dropsNullEnergyAndGhosts() {
        let good = candidate("Banana", kcal: 89)
        let zero = candidate("Ghost", kcal: 0)
        let nan = FoodCandidate(name: "Broken", brand: nil, source: .off, sourceID: "x", barcode: nil,
                                nutrition: FoodNutrition(kcalPer100: .nan, proteinPer100: 0,
                                                         carbsPer100: 0, fatPer100: 0, servingGrams: nil))
        let result = FoodRanking.sanitize([good, zero, nan])
        XCTAssertEqual(result.map(\.name), ["Banana"])
    }

    func testDedup_keepsHigherPrioritySource() {
        let off = candidate("Cola", source: .off, barcode: "123")
        let common = candidate("Cola", source: .common, barcode: "123")
        let result = FoodRanking.dedup([off, common])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.source, .common)
    }

    func testRank_exactBeatsPrefixBeatsContains() {
        let exact = candidate("Milk", id: "a")
        let prefix = candidate("Milk Chocolate", id: "b")
        let contains = candidate("Almond Milk", id: "c")
        let ranked = FoodRanking.rank([contains, prefix, exact], query: "milk")
        XCTAssertEqual(ranked.map(\.name), ["Milk", "Milk Chocolate", "Almond Milk"])
    }

    func testRank_isStableOnTies_byNameThenID() {
        // Same score (both plain contains, same source); ties break by name asc then id.
        let a = candidate("Zucchini bread", source: .off, id: "id-2")
        let b = candidate("Apple bread", source: .off, id: "id-1")
        let ranked = FoodRanking.rank([a, b], query: "bread")
        XCTAssertEqual(ranked.map(\.name), ["Apple bread", "Zucchini bread"])
    }

    func testRank_servingSizeBoostsAmongEqualMatches() {
        let withServing = candidate("Yogurt", source: .off, serving: 170, id: "s")
        let without = candidate("Yogurt", source: .off, serving: nil, id: "n")
        // Different ids so dedup keeps both; the one with a serving should rank first.
        let ranked = FoodRanking.rank([without, withServing], query: "yogurt")
        XCTAssertEqual(ranked.first?.sourceID, "s")
    }
}
