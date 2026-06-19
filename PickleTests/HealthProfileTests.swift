import XCTest
@testable import Pickle

final class HealthProfileTests: XCTestCase {

    func testActivityInference_fromSteps() {
        func steps(_ n: Double) -> ActivityLevel? {
            BodyProfile(avgDailySteps: n).inferredActivity
        }
        XCTAssertEqual(steps(3000), .sedentary)
        XCTAssertEqual(steps(6000), .light)
        XCTAssertEqual(steps(9000), .moderate)
        XCTAssertEqual(steps(11000), .active)
        XCTAssertEqual(steps(15000), .veryActive)
    }

    func testActivityInference_fallsBackToActiveEnergyWhenNoSteps() {
        XCTAssertEqual(BodyProfile(avgDailyActiveEnergy: 150).inferredActivity, .sedentary)
        XCTAssertEqual(BodyProfile(avgDailyActiveEnergy: 700).inferredActivity, .active)
    }

    func testActivityInference_nilWhenNoData() {
        XCTAssertNil(BodyProfile().inferredActivity)
    }

    func testMerge_appliesOnlyPresentFields() {
        var data = ProfileData()
        data.weightKg = 75; data.activity = .moderate
        let bp = BodyProfile(weightKg: 82, leanMassKg: 64, sex: .male, age: 28, avgDailySteps: 11000)
        data.merge(health: bp)
        XCTAssertEqual(data.weightKg, 82)
        XCTAssertEqual(data.leanMassKg, 64)
        XCTAssertEqual(data.age, 28)
        XCTAssertEqual(data.activity, .active)   // inferred from 11k steps
    }

    func testMerge_leavesDefaultsWhenHealthEmpty() {
        var data = ProfileData()
        data.weightKg = 70
        data.merge(health: BodyProfile())
        XCTAssertEqual(data.weightKg, 70)
        XCTAssertEqual(data.leanMassKg, 0)
    }
}
