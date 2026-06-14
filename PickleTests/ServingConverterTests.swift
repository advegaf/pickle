import XCTest
@testable import Pickle

final class ServingConverterTests: XCTestCase {

    func testConvert_withinMass() {
        XCTAssertEqual(ServingConverter.convert(16, from: .ounce, to: .gram)!, 453.59, accuracy: 0.1)
        XCTAssertEqual(ServingConverter.convert(1, from: .pound, to: .gram)!, 453.592, accuracy: 0.1)
    }

    func testConvert_withinVolume() {
        XCTAssertEqual(ServingConverter.convert(1, from: .cup, to: .milliliter)!, 240, accuracy: 0.01)
        XCTAssertEqual(ServingConverter.convert(1, from: .tablespoon, to: .teaspoon)!, 3, accuracy: 0.01)
    }

    func testConvert_crossDimension_isRefused() {
        XCTAssertNil(ServingConverter.convert(1, from: .cup, to: .gram))     // volume → mass
        XCTAssertNil(ServingConverter.convert(1, from: .gram, to: .milliliter))
        XCTAssertNil(ServingConverter.convert(1, from: .serving, to: .gram)) // count has no factor
    }

    func testGrams_massConvertsDirectly() {
        XCTAssertEqual(ServingConverter.grams(amount: 2, unit: .ounce, gramsPerServing: nil)!, 56.699, accuracy: 0.1)
    }

    func testGrams_countNeedsServingSize() {
        XCTAssertEqual(ServingConverter.grams(amount: 2, unit: .serving, gramsPerServing: 30)!, 60, accuracy: 0.01)
        XCTAssertNil(ServingConverter.grams(amount: 1, unit: .serving, gramsPerServing: nil))
        XCTAssertNil(ServingConverter.grams(amount: 1, unit: .piece, gramsPerServing: 0)) // 0 is invalid
    }

    func testGrams_volumeWithoutDensity_refuses() {
        XCTAssertNil(ServingConverter.grams(amount: 1, unit: .cup, gramsPerServing: 240))
    }

    func testMacros_scaleWithPortion_andStayConsistent() {
        let n = FoodNutrition(kcalPer100: 200, proteinPer100: 10, carbsPer100: 20, fatPer100: 8, servingGrams: 50)
        // 50g serving → half of per-100g.
        let m = ServingConverter.macros(n, amount: 1, unit: .serving)
        XCTAssertEqual(m?.kcal, 100)
        XCTAssertEqual(m?.proteinG, 5)
        XCTAssertEqual(m?.carbsG, 10)
        XCTAssertEqual(m?.fatG, 4)
    }

    func testMacros_unresolvablePortion_returnsNil() {
        let n = FoodNutrition(kcalPer100: 200, proteinPer100: 10, carbsPer100: 20, fatPer100: 8, servingGrams: nil)
        XCTAssertNil(ServingConverter.macros(n, amount: 1, unit: .serving))   // no serving grams
        XCTAssertNil(ServingConverter.macros(n, amount: 1, unit: .cup))       // volume, no density
    }
}
