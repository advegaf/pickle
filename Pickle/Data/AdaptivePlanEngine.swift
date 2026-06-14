import Foundation

/// Weekly adaptive recalibration — the "poor man's MacroFactor". Estimates the user's
/// true maintenance from the energy balance equation (what they actually ate vs how their
/// weight trended), then re-aims the target at their goal. Pure and fully unit-tested.
///
/// Energy balance: `intake − expenditure = ΔweightEnergy`, so
/// `maintenance = avgIntake − (ΔweightKg × 7700 / days)`.
enum AdaptivePlanEngine {

    /// Largest change applied in a single recalibration. Prevents wild week-to-week swings
    /// from noisy weight data.
    static let maxStepKcal = 250
    /// Reasonable absolute ceiling for a daily target.
    static let maxKcal = 6000
    /// A week needs at least this many logged days to be trustworthy.
    static let minLoggedDays = 4
    /// Below this kcal change we treat the target as unchanged.
    static let trivialChange = 20

    struct Input: Equatable, Sendable {
        var avgDailyIntakeKcal: Double
        var loggedDays: Int
        var windowDays: Int
        var weightStartKg: Double?
        var weightEndKg: Double?
    }

    enum Status: Equatable, Sendable {
        case adjusted
        case held              // data is fine but the target barely moved
        case notEnoughLogs
        case noWeightTrend
        case invalidData
    }

    struct Result: Equatable, Sendable {
        var newKcal: Int
        var macros: MacroTargets
        var status: Status
        var estimatedMaintenanceKcal: Int?
        var changed: Bool { status == .adjusted }

        var reason: String {
            switch status {
            case .adjusted: return "Adjusted from your logged intake and weight trend."
            case .held: return "Your target is holding steady — your intake matches your trend."
            case .notEnoughLogs: return "Keep logging — adaptive targets need a fuller week of data."
            case .noWeightTrend: return "Add a recent weight to enable adaptive targets."
            case .invalidData: return "Your target is holding steady."
            }
        }
    }

    static func recommend(currentKcal: Int, goal: PlanCalculator.Goal, input: Input) -> Result {
        let split = goal.split
        func keep(_ status: Status, maintenance: Int? = nil) -> Result {
            Result(newKcal: currentKcal,
                   macros: PlanCalculator.macros(forKcal: currentKcal, split: split),
                   status: status,
                   estimatedMaintenanceKcal: maintenance)
        }

        guard input.loggedDays >= minLoggedDays else { return keep(.notEnoughLogs) }
        guard let start = input.weightStartKg, let end = input.weightEndKg else {
            return keep(.noWeightTrend)
        }

        let days = max(input.windowDays, 1)
        let deltaKg = end - start
        let maintenance = input.avgDailyIntakeKcal - (deltaKg * PlanCalculator.kcalPerKg / Double(days))

        guard maintenance.isFinite, maintenance > 0 else { return keep(.invalidData) }

        let aimed = maintenance + PlanCalculator.dailyAdjustment(goal)
        var newKcal = Int(aimed.rounded())

        // Clamp the per-recalibration step, then the absolute bounds.
        newKcal = min(max(newKcal, currentKcal - maxStepKcal), currentKcal + maxStepKcal)
        newKcal = min(max(newKcal, PlanCalculator.minKcal), maxKcal)

        let status: Status = abs(newKcal - currentKcal) >= trivialChange ? .adjusted : .held
        return Result(newKcal: newKcal,
                      macros: PlanCalculator.macros(forKcal: newKcal, split: split),
                      status: status,
                      estimatedMaintenanceKcal: Int(maintenance.rounded()))
    }
}
