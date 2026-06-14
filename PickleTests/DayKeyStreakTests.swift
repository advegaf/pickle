import XCTest
@testable import Pickle

final class DayKeyStreakTests: XCTestCase {

    func testLocalDay_format() {
        // 2026-06-14 12:00 UTC → label in UTC.
        let date = Date(timeIntervalSince1970: 1_781_784_000) // 2026-06-18T12:00:00Z (approx)
        let label = DayKey.localDay(for: date, in: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(label.count, 10)
        XCTAssertEqual(label[label.index(label.startIndex, offsetBy: 4)], "-")
    }

    func testOrdinal_adjacentDaysDifferByOne_DSTProof() {
        // A US DST boundary (spring forward 2026-03-08) must still be exactly 1 day apart,
        // because ordinals are computed in UTC.
        let a = DayKey.ordinal("2026-03-07")!
        let b = DayKey.ordinal("2026-03-08")!
        let c = DayKey.ordinal("2026-03-09")!
        XCTAssertEqual(b - a, 1)
        XCTAssertEqual(c - b, 1)
    }

    func testShifted_movesByDays() {
        XCTAssertEqual(DayKey.shifted("2026-06-14", by: -1), "2026-06-13")
        XCTAssertEqual(DayKey.shifted("2026-03-01", by: -1), "2026-02-28")
        XCTAssertEqual(DayKey.shifted("2026-12-31", by: 1), "2027-01-01")
    }

    func testStreak_consecutiveDaysEndingToday() {
        let today = "2026-06-14"
        let days: Set<String> = ["2026-06-14", "2026-06-13", "2026-06-12"]
        XCTAssertEqual(StreakCalculator.currentStreak(loggedDays: days, today: today), 3)
    }

    func testStreak_gapBreaksTheRun() {
        let today = "2026-06-14"
        let days: Set<String> = ["2026-06-14", "2026-06-12", "2026-06-11"]
        XCTAssertEqual(StreakCalculator.currentStreak(loggedDays: days, today: today), 1)
    }

    func testStreak_yesterdayGraceKeepsItAlive() {
        let today = "2026-06-14" // not logged today
        let days: Set<String> = ["2026-06-13", "2026-06-12"]
        XCTAssertEqual(StreakCalculator.currentStreak(loggedDays: days, today: today), 2)
    }

    func testStreak_isZeroWhenNeitherTodayNorYesterdayLogged() {
        let today = "2026-06-14"
        let days: Set<String> = ["2026-06-10", "2026-06-09"]
        XCTAssertEqual(StreakCalculator.currentStreak(loggedDays: days, today: today), 0)
    }

    func testDaysLogged_countsDistinct() {
        let days: Set<String> = ["2026-06-14", "2026-06-13", "2026-06-13"]
        XCTAssertEqual(StreakCalculator.daysLogged(loggedDays: days), 2)
    }
}
