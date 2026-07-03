import XCTest
import SwiftData
@testable import Pickle

@MainActor
final class StoreTests: XCTestCase {

    private func makeStore() -> PickleStore { PickleStore.inMemory() }

    private func sampleCandidate(_ name: String = "Banana", barcode: String? = "0001") -> FoodCandidate {
        FoodCandidate(name: name, brand: nil, source: .off, sourceID: "off-1", barcode: barcode,
                      nutrition: FoodNutrition(kcalPer100: 89, proteinPer100: 1.1, carbsPer100: 23,
                                               fatPer100: 0.3, servingGrams: 118))
    }

    func testLog_addsEntry_andUpdatesTodayTotals() {
        let store = makeStore()
        let cand = sampleCandidate()
        let macros = cand.nutrition.macros(forGrams: 118)
        store.log(cand, amount: 1, unit: .serving, meal: .breakfast, macros: macros)

        let today = store.today()
        XCTAssertEqual(today.entries.count, 1)
        XCTAssertEqual(today.totals.kcal, macros.kcal)
        XCTAssertEqual(today.kcal(for: .breakfast), macros.kcal)
        XCTAssertEqual(today.loggedMealCount, 1)
    }

    func testLog_thenDelete_clearsDiary() {
        let store = makeStore()
        let cand = sampleCandidate()
        store.log(cand, amount: 1, unit: .serving, meal: .lunch, macros: cand.nutrition.macros(forGrams: 100))
        let id = store.today().entries.first!.id
        store.deleteLog(id: id)
        XCTAssertTrue(store.today().isEmpty)
    }

    func testUpdateLog_editsInPlace_keepsCount_updatesMacrosAndMeal() {
        let store = makeStore()
        let cand = sampleCandidate()
        store.log(cand, amount: 1, unit: .serving, meal: .lunch, macros: cand.nutrition.macros(forGrams: 118))
        let entry = store.today().entries.first!
        XCTAssertEqual(store.today().entries.count, 1)

        // Edit it to a 2-serving portion moved to dinner.
        let newMacros = cand.nutrition.macros(forGrams: 236)
        store.updateLog(id: entry.id, amount: 2, unit: .serving, meal: .dinner, macros: newMacros)

        let today = store.today()
        XCTAssertEqual(today.entries.count, 1)                 // edited, not duplicated
        let edited = today.entries.first!
        XCTAssertEqual(edited.meal, .dinner)
        XCTAssertEqual(edited.amount, 2)
        XCTAssertEqual(edited.macros.kcal, newMacros.kcal)
        XCTAssertEqual(today.kcal(for: .lunch), 0)            // moved off lunch
        XCTAssertEqual(today.kcal(for: .dinner), newMacros.kcal)
    }

    func testDeleteAllData_wipesEverything_andResetsOnboarding() {
        let store = makeStore()
        var data = ProfileData()
        data.name = "Alex"; data.sex = .male; data.age = 28; data.heightCm = 178; data.weightKg = 82
        data.activity = .active; data.goal = .lose; data.weeklyRateKg = 0.5; data.split = .highProtein
        store.completeOnboarding(data)

        let cand = sampleCandidate("Yogurt", barcode: "y")
        store.log(cand, amount: 1, unit: .serving, meal: .breakfast, macros: cand.nutrition.macros(forGrams: 170))
        store.upsertFood(from: cand)
        store.toggleFavorite(canonicalID: cand.canonicalID)
        store.addWeight(kg: 81.5)
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertFalse(store.today().isEmpty)
        XCTAssertFalse(store.favorites().isEmpty)

        store.deleteAllData()

        XCTAssertFalse(store.hasCompletedOnboarding)   // no profile -> back to onboarding
        XCTAssertTrue(store.today().isEmpty)
        XCTAssertTrue(store.favorites().isEmpty)
        XCTAssertTrue(store.lovedMeals().isEmpty)
        XCTAssertTrue(store.recents().isEmpty)
    }

    func testRecents_reflectLoggedFoods() {
        let store = makeStore()
        store.log(sampleCandidate("Apple", barcode: "a"), amount: 1, unit: .serving,
                  meal: .snack, macros: MacroTargets(kcal: 52, proteinG: 0, carbsG: 14, fatG: 0))
        XCTAssertTrue(store.recents().contains { $0.name == "Apple" })
    }

    func testFavoriteToggle() {
        let store = makeStore()
        let cand = sampleCandidate("Yogurt", barcode: "y")
        store.upsertFood(from: cand)
        store.toggleFavorite(canonicalID: cand.canonicalID)
        XCTAssertTrue(store.favorites().contains { $0.name == "Yogurt" })
    }

    func testDedupMerger_collapsesTwins_repointsLogs_keepsLowestUUID() {
        let store = makeStore()
        let ctx = store.context

        // Two same-canonicalID twins (as CloudKit would create across two offline devices).
        let cid = "barcode:9999"
        let a = FoodItemEntry(); a.uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        a.canonicalID = cid; a.name = "Cola"; a.isFavorite = true
        let b = FoodItemEntry(); b.uuid = UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")!
        b.canonicalID = cid; b.name = "Cola"; b.isCustom = true
        ctx.insert(a); ctx.insert(b)

        // A log attached to the higher-UUID twin (the loser).
        let log = LogEntry(); log.canonicalID = cid; log.name = "Cola"; log.food = b
        ctx.insert(log)
        try? ctx.save()

        let merged = DedupMerger.merge(in: ctx)
        XCTAssertEqual(merged, 1)

        let remaining = (try? ctx.fetch(FetchDescriptor<FoodItemEntry>())) ?? []
        XCTAssertEqual(remaining.count, 1)
        let keeper = remaining[0]
        XCTAssertEqual(keeper.uuid, a.uuid)              // lowest UUID kept
        XCTAssertTrue(keeper.isFavorite && keeper.isCustom) // flags merged
        XCTAssertEqual(log.food?.uuid, a.uuid)           // log re-pointed to keeper
    }

    func testCompleteOnboarding_buildsPlan_andPersists() {
        let store = makeStore()
        var data = ProfileData()
        data.name = "Alex"; data.sex = .male; data.age = 28; data.heightCm = 178; data.weightKg = 82
        data.activity = .active; data.goal = .lose; data.weeklyRateKg = 0.5; data.split = .highProtein
        store.completeOnboarding(data)

        XCTAssertTrue(store.hasCompletedOnboarding)
        let p = store.profile()
        XCTAssertEqual(p.name, "Alex")
        XCTAssertGreaterThan(p.targets.kcal, PlanCalculator.minKcal)
        XCTAssertFalse(store.planHistory().isEmpty)
    }
}
