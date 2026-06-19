import XCTest
@testable import Pickle

/// Phase 1 smoke test, proves the test target links against the app module.
/// Real engine tests (PlanCalculator, AdaptivePlanEngine, FoodRanking, ServingConverter,
/// streak/localDay, dedup, export, AI parsing) arrive in Phase 3.
final class ScaffoldTests: XCTestCase {
    func testWordmarkSpacing() {
        let mark = Wordmark()
        XCTAssertEqual(mark.text, "PICKLE")
    }
}
