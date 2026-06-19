import XCTest
@testable import Pickle

final class FoodDisplayTests: XCTestCase {

    private func cand(kcalPer100: Double, servingGrams: Double?, brand: String? = nil) -> FoodCandidate {
        FoodCandidate(name: "Egg", brand: brand, source: .common, sourceID: "egg", barcode: nil,
                      nutrition: FoodNutrition(kcalPer100: kcalPer100, proteinPer100: 13,
                                               carbsPer100: 1, fatPer100: 10, servingGrams: servingGrams))
    }

    func testDisplayDetail_perServing_whenServingKnown() {
        // 143 cal/100g over a 50 g serving -> ~72 cal/serving (not 143)
        XCTAssertEqual(cand(kcalPer100: 143, servingGrams: 50).displayDetail, "72 cal/serving")
    }

    func testDisplayDetail_per100g_whenNoServing() {
        XCTAssertEqual(cand(kcalPer100: 143, servingGrams: nil).displayDetail, "143 cal/100g")
    }

    func testDisplayDetail_includesBrand() {
        // 100 cal/100g over a 170 g serving -> 170 cal/serving (brand separated by spacing, no dot)
        XCTAssertEqual(cand(kcalPer100: 100, servingGrams: 170, brand: "Fage").displayDetail,
                       "Fage   170 cal/serving")
    }
}
