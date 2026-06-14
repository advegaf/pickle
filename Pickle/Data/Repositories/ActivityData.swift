import Foundation
import SwiftData

extension PickleStore {
    /// Total kcal logged per `localDay` across all history (one fetch).
    func dailyKcal() -> [String: Int] {
        let entries = (try? context.fetch(FetchDescriptor<LogEntry>())) ?? []
        var map: [String: Int] = [:]
        for e in entries where !e.localDay.isEmpty {
            map[e.localDay, default: 0] += e.kcal
        }
        return map
    }

    /// Distinct logged days, most recent first.
    func activeDays() -> [String] {
        Array(loggedDays()).sorted(by: >)
    }

    /// Lightweight stats for the Activity header.
    func activityStats() -> ActivityStats {
        let days = loggedDays()
        let kcal = dailyKcal()
        let loggedCount = days.count
        let total = kcal.values.reduce(0, +)
        let avg = loggedCount > 0 ? total / loggedCount : 0
        let streak = StreakCalculator.currentStreak(loggedDays: days, today: todayKey())
        return ActivityStats(streak: streak, daysLogged: loggedCount, avgKcal: avg)
    }
}

struct ActivityStats: Equatable, Sendable {
    let streak: Int
    let daysLogged: Int
    let avgKcal: Int
}
