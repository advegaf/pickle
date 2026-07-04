import Foundation

/// `localDay` is a `yyyy-MM-dd` string captured in the device's timezone at log time, and
/// stored on every entry. All "today"/calendar/streak logic runs on these strings via
/// integer day-ordinals computed in UTC, so it never breaks across DST or travel.
enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// The local-day label for a moment, in a given timezone.
    static func localDay(for date: Date, in timeZone: TimeZone = .current) -> String {
        let f = formatter
        f.timeZone = timeZone
        return f.string(from: date)
    }

    /// A stable integer day index for a `yyyy-MM-dd` label. Parsed in UTC (no DST), so
    /// adjacent calendar days always differ by exactly 1. nil if the label is malformed.
    static func ordinal(_ key: String) -> Int? {
        let f = formatter
        f.timeZone = TimeZone(identifier: "UTC")
        guard let date = f.date(from: key) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    /// The label `days` before/after another label (negative = earlier). nil if malformed.
    static func shifted(_ key: String, by days: Int) -> String? {
        guard let ord = ordinal(key) else { return nil }
        let date = Date(timeIntervalSince1970: Double(ord + days) * 86_400)
        let f = formatter
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    /// Weekday index (1 = Sunday ... 7 = Saturday, Calendar convention) for a label.
    /// Derived from the ordinal: day 0 (1970-01-01) was a Thursday (= 5).
    static func weekday(_ key: String) -> Int? {
        guard let ord = ordinal(key) else { return nil }
        return ((ord % 7) + 7 + 4) % 7 + 1
    }

    /// The label of the first day of the week containing `key`, honoring the locale's
    /// first weekday (1 = Sunday, 2 = Monday). Pure ordinal math: safe across DST,
    /// month, and year boundaries.
    static func weekStart(of key: String, firstWeekday: Int = Calendar.current.firstWeekday) -> String? {
        guard let wd = weekday(key) else { return nil }
        let daysSinceStart = (wd - firstWeekday + 7) % 7
        return shifted(key, by: -daysSinceStart)
    }

    /// Ordered week-start labels from one week to another (inclusive bounds; both are
    /// normalized to their own week starts). Empty if the range is malformed/inverted.
    static func weekStarts(from: String, to: String,
                           firstWeekday: Int = Calendar.current.firstWeekday) -> [String] {
        guard var cursor = weekStart(of: from, firstWeekday: firstWeekday),
              let end = weekStart(of: to, firstWeekday: firstWeekday),
              cursor <= end else { return [] }
        var out: [String] = []
        while cursor <= end {
            out.append(cursor)
            guard let next = shifted(cursor, by: 7) else { break }
            cursor = next
        }
        return out
    }

    /// A concrete moment inside a local day label: noon local time, immune to DST edges
    /// (used to backfill logs onto a viewed past day).
    static func date(from key: String, in timeZone: TimeZone = .current) -> Date? {
        let f = formatter
        f.timeZone = timeZone
        guard let midnight = f.date(from: key) else { return nil }
        return midnight.addingTimeInterval(12 * 3600)
    }
}

/// Current logging streak, computed purely from the set of days that have ≥1 log.
enum StreakCalculator {
    /// A streak is "alive" if you logged today or yesterday (a one-day grace). It counts
    /// the run of consecutive logged days ending at that most-recent live day.
    static func currentStreak(loggedDays: Set<String>, today: String) -> Int {
        let ordinals = Set(loggedDays.compactMap(DayKey.ordinal))
        guard let todayOrd = DayKey.ordinal(today) else { return 0 }

        let start: Int
        if ordinals.contains(todayOrd) { start = todayOrd }
        else if ordinals.contains(todayOrd - 1) { start = todayOrd - 1 }
        else { return 0 }

        var count = 0
        var cursor = start
        while ordinals.contains(cursor) {
            count += 1
            cursor -= 1
        }
        return count
    }

    /// Distinct days logged (all-time count).
    static func daysLogged(loggedDays: Set<String>) -> Int {
        Set(loggedDays.compactMap(DayKey.ordinal)).count
    }
}
