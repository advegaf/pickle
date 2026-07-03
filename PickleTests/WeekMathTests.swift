import XCTest
@testable import Pickle

/// Week-window math for the Home WeekStrip. Pure ordinal arithmetic (UTC), so these
/// hold across DST, month, and year boundaries.
final class WeekMathTests: XCTestCase {

    // 2026-07-03 is a Friday.
    func testWeekdayIndex() {
        XCTAssertEqual(DayKey.weekday("2026-07-03"), 6) // Friday (1 = Sunday)
        XCTAssertEqual(DayKey.weekday("1970-01-01"), 5) // Thursday, the epoch anchor
        XCTAssertEqual(DayKey.weekday("2026-07-05"), 1) // Sunday
    }

    func testWeekStartMondayLocale() {
        // firstWeekday 2 = Monday.
        XCTAssertEqual(DayKey.weekStart(of: "2026-07-03", firstWeekday: 2), "2026-06-29")
        // A Monday is its own week start.
        XCTAssertEqual(DayKey.weekStart(of: "2026-06-29", firstWeekday: 2), "2026-06-29")
        // A Sunday belongs to the week that started the previous Monday.
        XCTAssertEqual(DayKey.weekStart(of: "2026-07-05", firstWeekday: 2), "2026-06-29")
    }

    func testWeekStartSundayLocale() {
        // firstWeekday 1 = Sunday (US).
        XCTAssertEqual(DayKey.weekStart(of: "2026-07-03", firstWeekday: 1), "2026-06-28")
        XCTAssertEqual(DayKey.weekStart(of: "2026-06-28", firstWeekday: 1), "2026-06-28")
    }

    func testWeekStartAcrossMonthBoundary() {
        // Wed 2026-07-01's Monday-week starts in June.
        XCTAssertEqual(DayKey.weekStart(of: "2026-07-01", firstWeekday: 2), "2026-06-29")
    }

    func testWeekStartAcrossYearBoundary() {
        // Thu 2026-01-01's Monday-week starts in December 2025.
        XCTAssertEqual(DayKey.weekStart(of: "2026-01-01", firstWeekday: 2), "2025-12-29")
        // Dec 31 belongs to the same week.
        XCTAssertEqual(DayKey.weekStart(of: "2025-12-31", firstWeekday: 2), "2025-12-29")
    }

    func testWeekWindowIsSevenConsecutiveDays() {
        let start = DayKey.weekStart(of: "2026-07-03", firstWeekday: 2)!
        let week = (0..<7).compactMap { DayKey.shifted(start, by: $0) }
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first, "2026-06-29")
        XCTAssertEqual(week.last, "2026-07-05")
        let ords = week.compactMap(DayKey.ordinal)
        XCTAssertEqual(ords.last! - ords.first!, 6)
    }

    // MARK: Backfill date

    func testDateFromKeyRoundTrips() {
        // Noon of the label must map back to the same label in the same timezone.
        let tz = TimeZone(identifier: "America/Chicago")!
        let date = DayKey.date(from: "2026-07-01", in: tz)!
        XCTAssertEqual(DayKey.localDay(for: date, in: tz), "2026-07-01")
    }

    func testDateFromKeySurvivesDSTTransition() {
        // US DST spring-forward day (2026-03-08): noon still lands on the same label.
        let tz = TimeZone(identifier: "America/Chicago")!
        let date = DayKey.date(from: "2026-03-08", in: tz)!
        XCTAssertEqual(DayKey.localDay(for: date, in: tz), "2026-03-08")
    }

    func testDateFromMalformedKeyIsNil() {
        XCTAssertNil(DayKey.date(from: "garbage"))
    }
}
