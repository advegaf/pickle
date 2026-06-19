import Foundation

/// Pure nutrition math. Mifflin-St Jeor BMR → TDEE → goal-adjusted calorie target →
/// macro grams. No state, no I/O, fully unit-tested.
enum PlanCalculator {

    /// One kilogram of body mass ≈ 7700 kcal of energy.
    static let kcalPerKg = 7700.0

    /// A safe floor so aggressive goals never prescribe a starvation target.
    static let minKcal = 1200

    struct Profile: Equatable, Sendable {
        var sex: Sex
        var age: Int
        var heightCm: Double
        var weightKg: Double
        var activity: ActivityLevel
        /// Lean body mass in kg from Apple Health, when known. Enables the more accurate
        /// Katch-McArdle basal rate.
        var leanMassKg: Double? = nil
    }

    /// Which basal-rate formula a plan used, surfaced for transparency.
    enum BasalFormula: String, Sendable { case katchMcArdle, mifflinStJeor }

    static func basalFormula(_ p: Profile) -> BasalFormula {
        (p.leanMassKg ?? 0) > 0 ? .katchMcArdle : .mifflinStJeor
    }

    struct Goal: Equatable, Sendable {
        var direction: GoalDirection
        /// Desired body-mass change per week, in kg. Always >= 0; direction sets the sign.
        var weeklyRateKg: Double
        var split: MacroSplit
    }

    /// Basal metabolic rate (kcal/day). Uses Katch-McArdle when lean body mass is known
    /// (it accounts for muscle mass, so it is more accurate), else Mifflin-St Jeor.
    static func bmr(_ p: Profile) -> Double {
        if let lean = p.leanMassKg, lean > 0 {
            return 370 + 21.6 * lean
        }
        let base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age)
        return base + (p.sex == .male ? 5 : -161)
    }

    /// Total daily energy expenditure (kcal/day).
    static func tdee(_ p: Profile) -> Double {
        bmr(p) * p.activity.multiplier
    }

    /// Daily calorie adjustment implied by the weekly rate (signed: negative = deficit).
    static func dailyAdjustment(_ goal: Goal) -> Double {
        let magnitude = abs(goal.weeklyRateKg) * kcalPerKg / 7.0
        switch goal.direction {
        case .lose: return -magnitude
        case .gain: return +magnitude
        case .maintain: return 0
        }
    }

    /// Goal-adjusted daily calorie target, floored at `minKcal`.
    static func calorieTarget(_ p: Profile, _ goal: Goal) -> Int {
        let raw = tdee(p) + dailyAdjustment(goal)
        return max(Int(raw.rounded()), minKcal)
    }

    /// Split a calorie target into macro grams. Protein/carbs at 4 kcal/g, fat at 9.
    static func macros(forKcal kcal: Int, split: MacroSplit) -> MacroTargets {
        let p = Double(kcal) * split.protein / Atwater.protein
        let c = Double(kcal) * split.carbs / Atwater.carbs
        let f = Double(kcal) * split.fat / Atwater.fat
        return MacroTargets(kcal: kcal,
                            proteinG: Int(p.rounded()),
                            carbsG: Int(c.rounded()),
                            fatG: Int(f.rounded()))
    }

    /// Full plan from profile + goal.
    static func plan(_ p: Profile, _ goal: Goal) -> MacroTargets {
        macros(forKcal: calorieTarget(p, goal), split: goal.split)
    }
}
