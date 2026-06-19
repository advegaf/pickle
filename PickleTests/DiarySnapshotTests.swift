import XCTest
@testable import Pickle

final class DiarySnapshotTests: XCTestCase {

    private func snap(consumed: Int, target: Int) -> DiarySnapshot {
        DiarySnapshot(localDay: "2026-06-16", updatedAt: Date(timeIntervalSince1970: 0),
                      consumedKcal: consumed, targetKcal: target,
                      proteinG: 0, proteinTarget: 0, carbsG: 0, carbsTarget: 0,
                      fatG: 0, fatTarget: 0, mealsLogged: 0, mealsTotal: 4)
    }

    func testUnderTarget() {
        let s = snap(consumed: 1500, target: 2000)
        XCTAssertEqual(s.remainingKcal, 500)
        XCTAssertEqual(s.overKcal, 0)
        XCTAssertFalse(s.isOver)
    }

    func testAtTarget() {
        let s = snap(consumed: 2000, target: 2000)
        XCTAssertEqual(s.remainingKcal, 0)
        XCTAssertEqual(s.overKcal, 0)
        XCTAssertFalse(s.isOver)
    }

    func testOverTarget() {
        let s = snap(consumed: 2300, target: 2000)
        XCTAssertEqual(s.remainingKcal, 0)   // remaining clamps at 0
        XCTAssertEqual(s.overKcal, 300)      // ...and the overage is surfaced separately
        XCTAssertTrue(s.isOver)
    }
}
