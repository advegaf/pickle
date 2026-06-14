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
}
