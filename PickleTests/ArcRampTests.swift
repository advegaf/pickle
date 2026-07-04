import XCTest
@testable import Pickle

/// The progressive gauge ramp is pure math; these pin the Whoop stops, interpolation,
/// clamping, and the non-text contrast floor at every stop on the black canvas.
final class ArcRampTests: XCTestCase {

    func testStopsAreExactWhoopColors() {
        // White-ish start.
        XCTAssertEqual(ArcRamp.rgb(fraction: 0).r, 232)
        // Whoop green #16EC06.
        let green = ArcRamp.rgb(fraction: 0.30)
        XCTAssertEqual(green.r, 22); XCTAssertEqual(green.g, 236); XCTAssertEqual(green.b, 6)
        // Whoop yellow #FFDE00.
        let yellow = ArcRamp.rgb(fraction: 0.60)
        XCTAssertEqual(yellow.r, 255); XCTAssertEqual(yellow.g, 222); XCTAssertEqual(yellow.b, 0)
        // Goal orange #FF6F13 (midpoint of Whoop yellow -> Whoop red).
        let orange = ArcRamp.rgb(fraction: 1.0)
        XCTAssertEqual(orange.r, 255); XCTAssertEqual(orange.g, 111); XCTAssertEqual(orange.b, 19)
    }

    func testRedIsNotInTheRamp() {
        // Red is reserved for over-goal; the ramp must land on orange at 100%.
        let goal = ArcRamp.rgb(fraction: 1.0)
        XCTAssertGreaterThan(goal.g, 60, "Goal color should be orange, not Whoop red")
    }

    func testClampsOutsideUnitRange() {
        XCTAssertEqual(ArcRamp.rgb(fraction: -0.5).r, ArcRamp.rgb(fraction: 0).r)
        XCTAssertEqual(ArcRamp.rgb(fraction: 3.0).g, ArcRamp.rgb(fraction: 1).g)
    }

    func testMidpointInterpolatesLinearly() {
        // Halfway between white (0.0) and Whoop green (0.30).
        let mid = ArcRamp.rgb(fraction: 0.15)
        XCTAssertEqual(mid.r, (232.0 + 22.0) / 2, accuracy: 0.5)
        XCTAssertEqual(mid.g, (232.0 + 236.0) / 2, accuracy: 0.5)
        XCTAssertEqual(mid.b, (232.0 + 6.0) / 2, accuracy: 0.5)
    }

    // MARK: Contrast (non-text UI floor 3:1 on pure black)

    private func luminance(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        func lin(_ c: Double) -> Double {
            let v = c / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(rgb.r) + 0.7152 * lin(rgb.g) + 0.0722 * lin(rgb.b)
    }

    func testEveryStopClearsNonTextContrastOnBlack() {
        for stop in ArcRamp.stops {
            let ratio = (luminance(stop.rgb) + 0.05) / 0.05
            XCTAssertGreaterThanOrEqual(ratio, 3.0,
                "Ramp stop at \(stop.fraction) fails 3:1 on black")
        }
    }

    func testWhoopRedOverColorClearsContrastOnBlack() {
        // #FF0026 as a UI component color on black.
        let ratio = (luminance((255, 0, 38)) + 0.05) / 0.05
        XCTAssertGreaterThanOrEqual(ratio, 3.0)
    }
}
