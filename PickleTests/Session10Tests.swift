import XCTest
import SwiftData
@testable import Pickle

/// Coverage for the session-10 batch: curated Explore lists, the AI coaching summary, and the
/// loved-meal save/relog round-trip.
@MainActor
final class Session10Tests: XCTestCase {

    private func makeStore() -> PickleStore { PickleStore.inMemory() }

    private func onboardedStore() -> PickleStore {
        let store = makeStore()
        var data = ProfileData()
        data.name = "Alex"; data.sex = .male; data.age = 28; data.heightCm = 180; data.weightKg = 82
        data.activity = .active; data.goal = .lose; data.weeklyRateKg = 0.5; data.split = .highProtein
        store.completeOnboarding(data)
        return store
    }

    private func candidate(_ name: String) -> FoodCandidate {
        FoodCandidate(name: name, brand: nil, source: .common, sourceID: name.lowercased(),
                      barcode: nil,
                      nutrition: FoodNutrition(kcalPer100: 120, proteinPer100: 12, carbsPer100: 10,
                                               fatPer100: 4, servingGrams: 100))
    }

    // MARK: Curated Explore lists

    func testRecommended_everyCategory_returnsNonEmpty() throws {
        try XCTSkipIf(CommonFoods.all.isEmpty, "common_foods.json not bundled in this test host")
        for category in FoodCategory.allCases {
            let foods = CommonFoods.recommended(forCategory: category)
            XCTAssertFalse(foods.isEmpty, "category \(category.rawValue) returned no curated foods")
        }
    }

    func testRecommended_everyCollection_returnsNonEmpty() throws {
        try XCTSkipIf(CommonFoods.all.isEmpty, "common_foods.json not bundled in this test host")
        for collection in FoodCollection.all {
            let foods = CommonFoods.recommended(forCollection: collection)
            XCTAssertFalse(foods.isEmpty, "collection \(collection.id) returned no curated foods")
        }
    }

    func testRecommended_highProtein_isRankedByProteinDensity() throws {
        try XCTSkipIf(CommonFoods.all.isEmpty, "common_foods.json not bundled in this test host")
        let collection = try XCTUnwrap(FoodCollection.all.first { $0.id == "high-protein" })
        let foods = CommonFoods.recommended(forCollection: collection)
        XCTAssertGreaterThanOrEqual(foods.count, 2)
        // Sorted descending by protein per 100g.
        let proteins = foods.map { $0.nutrition.proteinPer100 }
        XCTAssertEqual(proteins, proteins.sorted(by: >))
    }

    func testRecommended_leanProtein_excludesHighFat() throws {
        try XCTSkipIf(CommonFoods.all.isEmpty, "common_foods.json not bundled in this test host")
        let collection = try XCTUnwrap(FoodCollection.all.first { $0.id == "lean-protein" })
        let foods = CommonFoods.recommended(forCollection: collection)
        XCTAssertFalse(foods.isEmpty)
        for food in foods {
            XCTAssertLessThanOrEqual(food.nutrition.fatPer100, 10, "\(food.name) is too fatty for lean protein")
            XCTAssertGreaterThanOrEqual(food.nutrition.proteinPer100, 8, "\(food.name) is not protein-dense")
        }
    }

    // MARK: AI coaching summary

    func testCoachingSummary_describesGoalAndTargets() {
        let store = onboardedStore()
        let summary = store.coachingSummary()
        XCTAssertTrue(summary.text.contains("Goal:"))
        XCTAssertTrue(summary.text.lowercased().contains("target"))
        XCTAssertFalse(summary.cacheKey.isEmpty)
    }

    func testCoachingSummary_cacheKeyMovesWhenDataChanges() {
        let store = onboardedStore()
        let before = store.coachingSummary().cacheKey
        store.log(candidate("Chicken Breast"), amount: 1, unit: .serving, meal: .lunch,
                  macros: MacroTargets(kcal: 165, proteinG: 31, carbsG: 0, fatG: 4))
        let after = store.coachingSummary().cacheKey
        XCTAssertNotEqual(before, after)
    }

    func testCoachingSummary_loggedDaysCountsToday() {
        let store = onboardedStore()
        XCTAssertEqual(store.coachingSummary().loggedDays, 0)
        store.log(candidate("Eggs"), amount: 1, unit: .serving, meal: .breakfast,
                  macros: MacroTargets(kcal: 140, proteinG: 12, carbsG: 1, fatG: 10))
        XCTAssertEqual(store.coachingSummary().loggedDays, 1)
    }

    func testCoachingSummary_framesByTenure_notFixedWindow() {
        // A brand-new user who logged once today has been "tracking" for 1 day, so the summary
        // must say "1 of 1", never "1 of 14" (which reads as falling short of a window they
        // never had). effectiveWindow == min(windowDays, daysSinceStart) == min(14, 1) == 1.
        let store = onboardedStore()
        store.log(candidate("Eggs"), amount: 1, unit: .serving, meal: .breakfast,
                  macros: MacroTargets(kcal: 140, proteinG: 12, carbsG: 1, fatG: 10))
        let text = store.coachingSummary().text
        XCTAssertTrue(text.contains("tracking for 1 day"), text)
        XCTAssertTrue(text.contains("logged 1 of 1"), text)
        XCTAssertFalse(text.contains("of 14"), "should not frame a new user against the full 14-day window")
    }

    // MARK: Loved meals

    func testLovedMeal_saveThenRelog_roundTrips() {
        let store = onboardedStore()
        store.log(candidate("Greek Yogurt"), amount: 1, unit: .serving, meal: .breakfast,
                  macros: MacroTargets(kcal: 100, proteinG: 17, carbsG: 6, fatG: 0))
        store.log(candidate("Granola"), amount: 1, unit: .serving, meal: .breakfast,
                  macros: MacroTargets(kcal: 200, proteinG: 5, carbsG: 30, fatG: 6))

        let breakfast = store.today().entries(for: .breakfast)
        XCTAssertEqual(breakfast.count, 2)
        store.saveLovedMeal(name: "Morning Bowl", from: breakfast)

        let meals = store.lovedMeals()
        XCTAssertEqual(meals.count, 1)
        let loved = meals[0]
        XCTAssertEqual(loved.name, "Morning Bowl")
        XCTAssertEqual(loved.itemCount, 2)
        XCTAssertEqual(loved.totals.kcal, 300)

        store.logLovedMeal(id: loved.id, into: .dinner)
        let dinner = store.today().entries(for: .dinner)
        XCTAssertEqual(dinner.count, 2)
        XCTAssertEqual(dinner.reduce(0) { $0 + $1.macros.kcal }, 300)
    }

    func testLovedMeal_delete_removesIt() {
        let store = onboardedStore()
        store.log(candidate("Oatmeal"), amount: 1, unit: .serving, meal: .breakfast,
                  macros: MacroTargets(kcal: 150, proteinG: 5, carbsG: 27, fatG: 3))
        store.saveLovedMeal(name: "Oats", from: store.today().entries(for: .breakfast))
        let id = store.lovedMeals()[0].id
        store.deleteLovedMeal(id: id)
        XCTAssertTrue(store.lovedMeals().isEmpty)
    }
}
