import Foundation
import SwiftData

extension PickleStore {
    /// Build the adaptive engine input over the trailing `windowDays`: average daily intake
    /// across days that were logged, how many days were logged, and the weight at each end
    /// of the window (first and last sample within it).
    func adaptiveInput(windowDays: Int = 14, endingOn today: String? = nil) -> AdaptivePlanEngine.Input {
        let endKey = today ?? todayKey()
        let startKey = DayKey.shifted(endKey, by: -(windowDays - 1)) ?? endKey
        guard let startOrd = DayKey.ordinal(startKey), let endOrd = DayKey.ordinal(endKey) else {
            return .init(avgDailyIntakeKcal: 0, loggedDays: 0, windowDays: windowDays,
                         weightStartKg: nil, weightEndKg: nil)
        }

        // Intake per logged day within the window.
        var kcalByDay: [String: Int] = [:]
        let allEntries = (try? context.fetch(FetchDescriptor<LogEntry>())) ?? []
        for entry in allEntries {
            guard let o = DayKey.ordinal(entry.localDay), o >= startOrd, o <= endOrd else { continue }
            kcalByDay[entry.localDay, default: 0] += entry.kcal
        }
        let loggedDays = kcalByDay.count
        let avg = loggedDays > 0 ? Double(kcalByDay.values.reduce(0, +)) / Double(loggedDays) : 0

        // Weight at each end of the window (closest samples inside it).
        let samples = weights().compactMap { s -> (Int, Double)? in
            guard let o = DayKey.ordinal(s.localDay), o >= startOrd, o <= endOrd else { return nil }
            return (o, s.kg)
        }.sorted { $0.0 < $1.0 }

        return AdaptivePlanEngine.Input(
            avgDailyIntakeKcal: avg,
            loggedDays: loggedDays,
            windowDays: windowDays,
            weightStartKg: samples.first?.1,
            weightEndKg: samples.last?.1
        )
    }

    /// The current adaptive recommendation, or nil if there's no profile/plan yet.
    func adaptiveRecommendation(windowDays: Int = 14) -> AdaptivePlanEngine.Result {
        let p = profile()
        return AdaptivePlanEngine.recommend(
            currentKcal: p.targets.kcal,
            goal: p.planGoal,
            input: adaptiveInput(windowDays: windowDays))
    }

    /// A compact, natural-language picture of the user's recent logging for the AI coach:
    /// goal and targets, average intake vs target, protein adherence today, weight trend,
    /// streak, and the estimated maintenance. The cache key changes once per day and whenever
    /// the numbers move, so the coach regenerates at most daily.
    func coachingSummary(windowDays: Int = 14) -> CoachingSummary {
        let p = profile()
        let input = adaptiveInput(windowDays: windowDays)
        let rec = adaptiveRecommendation(windowDays: windowDays)
        let samples = weights()
        let streak = StreakCalculator.currentStreak(loggedDays: loggedDays(), today: todayKey())
        let today = today().totals
        let t = p.targets

        var lines: [String] = []
        lines.append("Goal: \(p.goal.title). Daily target \(t.kcal) cal (protein \(t.proteinG) g, carbs \(t.carbsG) g, fat \(t.fatG) g).")

        if input.loggedDays > 0 {
            let avg = Int(input.avgDailyIntakeKcal.rounded())
            let delta = avg - t.kcal
            let vs = delta == 0 ? "right on target" : "\(abs(delta)) cal \(delta > 0 ? "over" : "under") target"
            lines.append("Last \(windowDays) days: logged \(input.loggedDays) of \(windowDays) days, averaging \(avg) cal/day (\(vs)).")
        } else {
            lines.append("No days logged in the last \(windowDays) days yet.")
        }

        if t.proteinG > 0 {
            let pct = Int((Double(today.proteinG) / Double(t.proteinG) * 100).rounded())
            lines.append("Today so far: \(today.kcal) cal, protein \(today.proteinG) of \(t.proteinG) g (\(pct)%).")
        }

        if let first = samples.first, let last = samples.last, samples.count >= 2 {
            let deltaLb = (last.kg - first.kg) * 2.2046226
            if abs(deltaLb) < 0.3 {
                lines.append("Weight is flat over the window.")
            } else {
                lines.append(String(format: "Weight trend: %@%.1f lb over the window.", deltaLb > 0 ? "+" : "", deltaLb))
            }
        }

        if let maintenance = rec.estimatedMaintenanceKcal {
            lines.append("Estimated true maintenance is about \(maintenance) cal/day.")
        }
        lines.append("Current logging streak: \(streak) day\(streak == 1 ? "" : "s").")

        let weightKey = samples.last.map { Int(($0.kg * 10).rounded()) } ?? 0
        let cacheKey = "\(todayKey())|d=\(input.loggedDays)|avg=\(Int(input.avgDailyIntakeKcal.rounded()))|w=\(weightKey)|t=\(t.kcal)|p=\(t.proteinG)|streak=\(streak)"

        return CoachingSummary(text: lines.joined(separator: "\n"),
                               cacheKey: cacheKey,
                               loggedDays: input.loggedDays)
    }
}
