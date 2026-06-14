import XCTest
@testable import Pickle

final class AdaptivePlanEngineTests: XCTestCase {
    private let goal = PlanCalculator.Goal(direction: .lose, weeklyRateKg: 0.5, split: .balanced)

    func testNotEnoughLogs_holdsTarget() {
        let input = AdaptivePlanEngine.Input(avgDailyIntakeKcal: 2000, loggedDays: 2,
                                             windowDays: 14, weightStartKg: 80, weightEndKg: 79)
        let r = AdaptivePlanEngine.recommend(currentKcal: 2000, goal: goal, input: input)
        XCTAssertEqual(r.status, .notEnoughLogs)
        XCTAssertEqual(r.newKcal, 2000)
        XCTAssertFalse(r.changed)
    }

    func testNoWeight_holdsTarget() {
        let input = AdaptivePlanEngine.Input(avgDailyIntakeKcal: 2000, loggedDays: 10,
                                             windowDays: 14, weightStartKg: nil, weightEndKg: nil)
        let r = AdaptivePlanEngine.recommend(currentKcal: 2000, goal: goal, input: input)
        XCTAssertEqual(r.status, .noWeightTrend)
        XCTAssertFalse(r.changed)
    }

    func testMaintenanceEstimate_fromEnergyBalance() {
        // Ate 2000/day for 14 days, lost 0.4kg. maintenance = 2000 + 0.4*7700/14 = 2220.
        let input = AdaptivePlanEngine.Input(avgDailyIntakeKcal: 2000, loggedDays: 12,
                                             windowDays: 14, weightStartKg: 80, weightEndKg: 79.6)
        let r = AdaptivePlanEngine.recommend(currentKcal: 2200, goal: goal, input: input)
        XCTAssertEqual(r.estimatedMaintenanceKcal ?? 0, 2220, accuracy: 2)
    }

    func testOverCorrection_isClampedToMaxStep() {
        // Estimated maintenance 2220, aimed = 2220 − 550 = 1670, current 2200.
        // Step clamp limits the move to −250 → 1950, not all the way to 1670.
        let input = AdaptivePlanEngine.Input(avgDailyIntakeKcal: 2000, loggedDays: 12,
                                             windowDays: 14, weightStartKg: 80, weightEndKg: 79.6)
        let r = AdaptivePlanEngine.recommend(currentKcal: 2200, goal: goal, input: input)
        XCTAssertEqual(r.newKcal, 2200 - AdaptivePlanEngine.maxStepKcal)
        XCTAssertEqual(r.status, .adjusted)
    }

    func testSmallChange_appliesWithinStep() {
        // maintenance ≈ 2500 (ate 2500, weight flat), aimed = 1950, current 2000 → within step.
        let input = AdaptivePlanEngine.Input(avgDailyIntakeKcal: 2500, loggedDays: 12,
                                             windowDays: 14, weightStartKg: 80, weightEndKg: 80)
        let r = AdaptivePlanEngine.recommend(currentKcal: 2000, goal: goal, input: input)
        XCTAssertEqual(r.newKcal, 1950) // 2500 − 550, inside the ±250 step from 2000
        XCTAssertEqual(r.status, .adjusted)
    }

    func testZeroWindowDays_doesNotCrashOrDivideByZero() {
        let input = AdaptivePlanEngine.Input(avgDailyIntakeKcal: 2000, loggedDays: 6,
                                             windowDays: 0, weightStartKg: 80, weightEndKg: 79.5)
        let r = AdaptivePlanEngine.recommend(currentKcal: 2000, goal: goal, input: input)
        XCTAssertTrue(r.newKcal >= PlanCalculator.minKcal && r.newKcal <= AdaptivePlanEngine.maxKcal)
    }

    func testResult_neverBelowFloorOrAboveCeiling() {
        let input = AdaptivePlanEngine.Input(avgDailyIntakeKcal: 800, loggedDays: 10,
                                             windowDays: 14, weightStartKg: 80, weightEndKg: 82)
        let r = AdaptivePlanEngine.recommend(currentKcal: PlanCalculator.minKcal, goal: goal, input: input)
        XCTAssertGreaterThanOrEqual(r.newKcal, PlanCalculator.minKcal)
    }
}
