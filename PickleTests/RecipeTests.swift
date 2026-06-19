import XCTest
@testable import Pickle

@MainActor
final class RecipeTests: XCTestCase {

    func testRecipeTotals_sumIngredientMacros() {
        let r = try! XCTUnwrap(Recipe.all.first { $0.id == "chicken-rice" })
        let expected = r.items.reduce(MacroTargets.zero) { $0 + $1.macros }
        XCTAssertEqual(r.totals, expected)
        XCTAssertGreaterThan(r.totals.kcal, 0)
        XCTAssertGreaterThan(r.totals.proteinG, 0)
    }

    func testRecipeLogAll_landsEveryItemInTheDiary() {
        let store = PickleStore.inMemory()
        let r = try! XCTUnwrap(Recipe.all.first)
        for item in r.items {
            store.log(item.candidate, amount: 1, unit: .serving, meal: .breakfast, macros: item.macros)
        }
        let today = store.today()
        XCTAssertEqual(today.entries.count, r.items.count)
        XCTAssertEqual(today.totals.kcal, r.totals.kcal)
    }
}
