import XCTest
@testable import Pickle

final class PlanCalculatorTests: XCTestCase {

    func testBMR_male_matchesMifflinStJeor() {
        // 80kg, 180cm, 30y male: 10*80 + 6.25*180 − 5*30 + 5 = 1780
        let p = PlanCalculator.Profile(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate)
        XCTAssertEqual(PlanCalculator.bmr(p), 1780, accuracy: 0.01)
    }

    func testBMR_female_matchesMifflinStJeor() {
        // 65kg, 165cm, 30y female: 650 + 1031.25 − 150 − 161 = 1370.25
        let p = PlanCalculator.Profile(sex: .female, age: 30, heightCm: 165, weightKg: 65, activity: .light)
        XCTAssertEqual(PlanCalculator.bmr(p), 1370.25, accuracy: 0.01)
    }

    func testTDEE_appliesActivityMultiplier() {
        let p = PlanCalculator.Profile(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate)
        XCTAssertEqual(PlanCalculator.tdee(p), 1780 * 1.55, accuracy: 0.01)
    }

    func testDailyAdjustment_lossIsNegative_gainIsPositive() {
        let lose = PlanCalculator.Goal(direction: .lose, weeklyRateKg: 0.5, split: .balanced)
        XCTAssertEqual(PlanCalculator.dailyAdjustment(lose), -550, accuracy: 0.01) // 0.5*7700/7
        let gain = PlanCalculator.Goal(direction: .gain, weeklyRateKg: 0.25, split: .balanced)
        XCTAssertEqual(PlanCalculator.dailyAdjustment(gain), 275, accuracy: 0.01)
        let maintain = PlanCalculator.Goal(direction: .maintain, weeklyRateKg: 0.5, split: .balanced)
        XCTAssertEqual(PlanCalculator.dailyAdjustment(maintain), 0, accuracy: 0.01)
    }

    func testCalorieTarget_flooredAtMinimum() {
        // Tiny person + aggressive deficit must never drop below the floor.
        let p = PlanCalculator.Profile(sex: .female, age: 60, heightCm: 150, weightKg: 45, activity: .sedentary)
        let goal = PlanCalculator.Goal(direction: .lose, weeklyRateKg: 1.0, split: .balanced)
        XCTAssertGreaterThanOrEqual(PlanCalculator.calorieTarget(p, goal), PlanCalculator.minKcal)
    }

    func testMacros_splitSumsToCalories_andSplitsValid() {
        let m = PlanCalculator.macros(forKcal: 2200, split: .balanced)
        // Protein 30% /4 = 165, Carbs 40% /4 = 220, Fat 30% /9 = 73
        XCTAssertEqual(m.proteinG, 165)
        XCTAssertEqual(m.carbsG, 220)
        XCTAssertEqual(m.fatG, 73)
        XCTAssertTrue(MacroSplit.balanced.isValid)
        XCTAssertTrue(MacroSplit.highProtein.isValid)
        XCTAssertTrue(MacroSplit.lowCarb.isValid)
    }

    func testFullPlan_isConsistent() {
        let p = PlanCalculator.Profile(sex: .male, age: 28, heightCm: 178, weightKg: 82, activity: .active)
        let goal = PlanCalculator.Goal(direction: .lose, weeklyRateKg: 0.5, split: .highProtein)
        let plan = PlanCalculator.plan(p, goal)
        XCTAssertGreaterThan(plan.kcal, PlanCalculator.minKcal)
        // Implied kcal from macro grams should be within rounding distance of the target.
        XCTAssertEqual(plan.impliedKcal, Double(plan.kcal), accuracy: 12)
    }
}
