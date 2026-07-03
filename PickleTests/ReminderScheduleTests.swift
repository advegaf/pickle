import XCTest
@testable import Pickle

/// The reminder schedule math is pure (`ReminderScheduleBuilder`); these tests pin the
/// request specs, suppression behavior, identifier parsing, privacy copy, and the
/// bell-dot logic without ever touching UNUserNotificationCenter.
final class ReminderScheduleTests: XCTestCase {

    private func settings(enabled: [MealSlot], hour: Int = 9, minute: Int = 15) -> ReminderSettings {
        var s = ReminderSettings.initial
        for meal in enabled {
            s.meals[meal.rawValue] = .init(enabled: true, hour: hour, minute: minute)
        }
        return s
    }

    // MARK: Specs

    func testDisabledMealsProduceNoSpecs() {
        let specs = ReminderScheduleBuilder.specs(settings: .initial, suppressed: [:], today: "2026-07-03")
        XCTAssertTrue(specs.isEmpty)
    }

    func testEnabledMealsProduceRepeatingSpecsWithTimes() {
        let specs = ReminderScheduleBuilder.specs(settings: settings(enabled: [.breakfast, .lunch]),
                                                  suppressed: [:], today: "2026-07-03")
        XCTAssertEqual(specs.count, 2)
        for spec in specs {
            XCTAssertTrue(spec.repeats)
            XCTAssertEqual(spec.dateComponents.hour, 9)
            XCTAssertEqual(spec.dateComponents.minute, 15)
            XCTAssertNil(spec.dateComponents.day) // repeating: time-only components
        }
    }

    func testNeverMoreThanFourPendingSpecs() {
        let specs = ReminderScheduleBuilder.specs(settings: settings(enabled: MealSlot.allCases),
                                                  suppressed: [:], today: "2026-07-03")
        XCTAssertEqual(specs.count, 4)
    }

    // MARK: Suppression (logged meal skips today's fire via a one-shot for tomorrow)

    func testSuppressedMealBecomesOneShotForTomorrow() {
        let specs = ReminderScheduleBuilder.specs(
            settings: settings(enabled: [.lunch]),
            suppressed: [MealSlot.lunch.rawValue: "2026-07-03"],
            today: "2026-07-03")
        XCTAssertEqual(specs.count, 1)
        let spec = specs[0]
        XCTAssertFalse(spec.repeats)
        XCTAssertEqual(spec.identifier, "pickle.reminder.once.lunch")
        XCTAssertEqual(spec.dateComponents.year, 2026)
        XCTAssertEqual(spec.dateComponents.month, 7)
        XCTAssertEqual(spec.dateComponents.day, 4)
        XCTAssertEqual(spec.dateComponents.hour, 9)
    }

    func testSuppressionOneShotCrossesMonthBoundary() {
        let specs = ReminderScheduleBuilder.specs(
            settings: settings(enabled: [.dinner]),
            suppressed: [MealSlot.dinner.rawValue: "2026-07-31"],
            today: "2026-07-31")
        XCTAssertEqual(specs[0].dateComponents.month, 8)
        XCTAssertEqual(specs[0].dateComponents.day, 1)
    }

    func testStaleSuppressionIsIgnored() {
        // Suppressed for YESTERDAY: today's repeating trigger is back.
        let specs = ReminderScheduleBuilder.specs(
            settings: settings(enabled: [.lunch]),
            suppressed: [MealSlot.lunch.rawValue: "2026-07-02"],
            today: "2026-07-03")
        XCTAssertTrue(specs[0].repeats)
    }

    // MARK: Privacy

    func testBodyCopyIsGenericPerMeal() {
        for meal in MealSlot.allCases {
            let body = ReminderScheduleBuilder.body(for: meal)
            XCTAssertEqual(body, "Time to log \(meal.title.lowercased())")
        }
    }

    // MARK: Identifier parsing (notification tap -> meal routing)

    func testMealFromIdentifierRoundTrips() {
        for meal in MealSlot.allCases {
            XCTAssertEqual(ReminderScheduleBuilder.meal(
                fromIdentifier: ReminderScheduleBuilder.identifier(for: meal)), meal)
            XCTAssertEqual(ReminderScheduleBuilder.meal(
                fromIdentifier: ReminderScheduleBuilder.identifier(for: meal, oneShot: true)), meal)
        }
        XCTAssertNil(ReminderScheduleBuilder.meal(fromIdentifier: "some.other.notification"))
    }

    // MARK: Bell dot

    private func dayWith(_ meals: [MealSlot]) -> DiaryDay {
        DiaryDay(localDay: "2026-07-03", entries: meals.map { meal in
            LoggedFood(id: UUID(), loggedAt: Date(), localDay: "2026-07-03", meal: meal,
                       name: "x", brand: nil, canonicalID: "x", amount: 1, unit: .serving,
                       macros: MacroTargets(kcal: 100, proteinG: 1, carbsG: 1, fatG: 1))
        })
    }

    func testMissedCountsFiredUnloggedMealsOnly() {
        let s = settings(enabled: [.breakfast, .lunch]) // both fire at 9:15
        // 10:00: both fired; breakfast logged, lunch not -> 1 missed.
        XCTAssertEqual(ReminderScheduleBuilder.missedCount(
            settings: s, today: dayWith([.breakfast]), suppressed: [:],
            todayKey: "2026-07-03", minutesNow: 10 * 60), 1)
    }

    func testMissedIsZeroBeforeFireTime() {
        let s = settings(enabled: [.breakfast])
        XCTAssertEqual(ReminderScheduleBuilder.missedCount(
            settings: s, today: dayWith([]), suppressed: [:],
            todayKey: "2026-07-03", minutesNow: 8 * 60), 0)
    }

    func testSuppressedMealNeverCountsAsMissed() {
        let s = settings(enabled: [.lunch])
        XCTAssertEqual(ReminderScheduleBuilder.missedCount(
            settings: s, today: dayWith([]), suppressed: [MealSlot.lunch.rawValue: "2026-07-03"],
            todayKey: "2026-07-03", minutesNow: 12 * 60), 0)
    }
}
