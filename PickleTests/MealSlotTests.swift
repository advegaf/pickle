import XCTest
@testable import Pickle

/// The time-of-day default meal mapping used when logging from the generic Log pill.
final class MealSlotTests: XCTestCase {
    private func date(hour: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 15; c.hour = hour; c.minute = 30
        return Calendar.current.date(from: c)!
    }

    func testCurrentMealAcrossTheDay() {
        XCTAssertEqual(MealSlot.current(at: date(hour: 4)), .breakfast)
        XCTAssertEqual(MealSlot.current(at: date(hour: 7)), .breakfast)
        XCTAssertEqual(MealSlot.current(at: date(hour: 10)), .breakfast)
        XCTAssertEqual(MealSlot.current(at: date(hour: 11)), .lunch)
        XCTAssertEqual(MealSlot.current(at: date(hour: 13)), .lunch)
        XCTAssertEqual(MealSlot.current(at: date(hour: 15)), .lunch)
        XCTAssertEqual(MealSlot.current(at: date(hour: 16)), .dinner)
        XCTAssertEqual(MealSlot.current(at: date(hour: 19)), .dinner)
        XCTAssertEqual(MealSlot.current(at: date(hour: 21)), .dinner)
        XCTAssertEqual(MealSlot.current(at: date(hour: 22)), .snack)
        XCTAssertEqual(MealSlot.current(at: date(hour: 0)), .snack)
        XCTAssertEqual(MealSlot.current(at: date(hour: 3)), .snack)
    }
}
