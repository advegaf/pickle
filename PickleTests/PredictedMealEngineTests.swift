import XCTest
@testable import Pickle

/// The prediction engine is pure and deterministic; these tests pin its tiers,
/// tie-breaking, median-time math, and slot selection.
final class PredictedMealEngineTests: XCTestCase {

    // MARK: Fixtures

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    private func date(_ day: String, _ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        let parts = day.split(separator: "-").map { Int($0)! }
        comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
        comps.hour = hour; comps.minute = minute
        comps.timeZone = cal.timeZone
        return cal.date(from: comps)!
    }

    private func food(_ name: String, id: String? = nil, meal: MealSlot,
                      day: String, hour: Int, minute: Int = 0, kcal: Int = 300) -> LoggedFood {
        LoggedFood(id: UUID(), loggedAt: date(day, hour, minute), localDay: day, meal: meal,
                   name: name, brand: nil, canonicalID: id ?? name.lowercased(),
                   amount: 1, unit: .serving,
                   macros: MacroTargets(kcal: kcal, proteinG: 20, carbsG: 30, fatG: 10))
    }

    private func day(_ key: String, _ entries: [LoggedFood]) -> DiaryDay {
        DiaryDay(localDay: key, entries: entries)
    }

    private let emptyToday = DiaryDay(localDay: "2026-07-03", entries: [])

    // MARK: Tiers

    func testEmptyHistoryYieldsNudgeForBreakfast() {
        let p = PredictedMealEngine.predict(history: [], today: emptyToday, calendar: cal)
        XCTAssertEqual(p?.slot, .breakfast)
        XCTAssertNil(p?.food)
    }

    func testFewerThanThreeOccurrencesFallsBackToMostRecent() {
        let history = [
            day("2026-07-01", [food("Oats", meal: .breakfast, day: "2026-07-01", hour: 8)]),
            day("2026-07-02", [food("Eggs", meal: .breakfast, day: "2026-07-02", hour: 9)]),
        ]
        let p = PredictedMealEngine.predict(history: history, today: emptyToday, calendar: cal)
        XCTAssertEqual(p?.food?.name, "Eggs") // tier 2: most recent, no >= 3 winner
    }

    func testFrequencyWinnerAtThreeOccurrences() {
        let history = [
            day("2026-06-30", [food("Oats", meal: .breakfast, day: "2026-06-30", hour: 8)]),
            day("2026-07-01", [food("Oats", meal: .breakfast, day: "2026-07-01", hour: 8)]),
            day("2026-07-02", [food("Oats", meal: .breakfast, day: "2026-07-02", hour: 8),
                               food("Eggs", meal: .breakfast, day: "2026-07-02", hour: 9)]),
        ]
        let p = PredictedMealEngine.predict(history: history, today: emptyToday, calendar: cal)
        XCTAssertEqual(p?.food?.name, "Oats")
    }

    func testFrequencyTieBreaksByMostRecent() {
        let history = [
            day("2026-06-29", [food("Oats", meal: .breakfast, day: "2026-06-29", hour: 8),
                               food("Eggs", meal: .breakfast, day: "2026-06-29", hour: 9)]),
            day("2026-06-30", [food("Oats", meal: .breakfast, day: "2026-06-30", hour: 8),
                               food("Eggs", meal: .breakfast, day: "2026-06-30", hour: 9)]),
            day("2026-07-01", [food("Oats", meal: .breakfast, day: "2026-07-01", hour: 8)]),
            day("2026-07-02", [food("Eggs", meal: .breakfast, day: "2026-07-02", hour: 9)]),
        ]
        // Both have 3 occurrences; Eggs was logged more recently (Jul 2 > Jul 1).
        let p = PredictedMealEngine.predict(history: history, today: emptyToday, calendar: cal)
        XCTAssertEqual(p?.food?.name, "Eggs")
    }

    func testMedianTimeIsUsedForTheWinner() {
        let history = [
            day("2026-06-30", [food("Oats", meal: .breakfast, day: "2026-06-30", hour: 7, minute: 30)]),
            day("2026-07-01", [food("Oats", meal: .breakfast, day: "2026-07-01", hour: 8, minute: 0)]),
            day("2026-07-02", [food("Oats", meal: .breakfast, day: "2026-07-02", hour: 10, minute: 15)]),
        ]
        let p = PredictedMealEngine.predict(history: history, today: emptyToday, calendar: cal)
        XCTAssertEqual(p?.food?.minutesSinceMidnight, 8 * 60) // median of 7:30, 8:00, 10:15
    }

    func testSkipsLoggedSlotsAndTargetsFirstUnlogged() {
        let today = day("2026-07-03", [food("Oats", meal: .breakfast, day: "2026-07-03", hour: 8)])
        let history = [
            day("2026-07-01", [food("Salad", meal: .lunch, day: "2026-07-01", hour: 12)]),
            day("2026-07-02", [food("Salad", meal: .lunch, day: "2026-07-02", hour: 12)]),
            day("2026-06-30", [food("Salad", meal: .lunch, day: "2026-06-30", hour: 13)]),
        ]
        let p = PredictedMealEngine.predict(history: history, today: today, calendar: cal)
        XCTAssertEqual(p?.slot, .lunch)
        XCTAssertEqual(p?.food?.name, "Salad")
    }

    func testAllSlotsLoggedYieldsNil() {
        let today = day("2026-07-03", MealSlot.allCases.map {
            food("Meal", id: "m-\($0.rawValue)", meal: $0, day: "2026-07-03", hour: 12)
        })
        XCTAssertNil(PredictedMealEngine.predict(history: [], today: today, calendar: cal))
    }

    func testMostRecentOccurrenceCarriesNameAndKcal() {
        let history = [
            day("2026-06-30", [food("Oats", meal: .breakfast, day: "2026-06-30", hour: 8, kcal: 300)]),
            day("2026-07-01", [food("Oats", meal: .breakfast, day: "2026-07-01", hour: 8, kcal: 310)]),
            day("2026-07-02", [food("Oats", meal: .breakfast, day: "2026-07-02", hour: 8, kcal: 350)]),
        ]
        let p = PredictedMealEngine.predict(history: history, today: emptyToday, calendar: cal)
        XCTAssertEqual(p?.food?.kcal, 350) // portions drift; the latest one wins
    }

    func testDeterministic() {
        let history = [
            day("2026-07-01", [food("Oats", meal: .breakfast, day: "2026-07-01", hour: 8),
                               food("Eggs", meal: .breakfast, day: "2026-07-01", hour: 8)]),
            day("2026-07-02", [food("Toast", meal: .breakfast, day: "2026-07-02", hour: 8)]),
        ]
        let a = PredictedMealEngine.predict(history: history, today: emptyToday, calendar: cal)
        let b = PredictedMealEngine.predict(history: history, today: emptyToday, calendar: cal)
        XCTAssertEqual(a, b)
    }
}
