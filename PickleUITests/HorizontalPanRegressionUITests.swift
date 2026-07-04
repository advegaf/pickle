import XCTest

/// Guards against screens becoming horizontally pannable (content extent wider than the
/// scroll view). Regression: after cards adopted Liquid Glass, every screen could be
/// dragged freely left/right. The probe measures a known element's frame before and
/// after a horizontal swipe; on a healthy vertical-only screen it must not move.
final class HorizontalPanRegressionUITests: XCTestCase {

    @MainActor
    func testHomeDoesNotPanHorizontally() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "--reset-position"]
        app.launch()

        // The greeting is always present on the seeded Home.
        let greeting = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Good'")).firstMatch
        XCTAssertTrue(greeting.waitForExistence(timeout: 10), "Seeded Home should show the greeting")

        let before = greeting.frame.origin.x

        // Drag horizontally across the middle of the screen (slow drag, not a flick,
        // so a pannable scroll view would visibly translate and stay).
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)

        // Let any scroll settle.
        Thread.sleep(forTimeInterval: 0.8)

        let after = greeting.frame.origin.x
        XCTAssertEqual(before, after, accuracy: 2,
                       "Home content moved horizontally by \(after - before)pt - the screen is pannable sideways")
    }

    @MainActor
    func testExploreDoesNotPanHorizontally() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "--tab", "1"]
        app.launch()

        let title = app.staticTexts["Explore"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        let before = title.frame.origin.x
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
        Thread.sleep(forTimeInterval: 0.8)

        XCTAssertEqual(before, title.frame.origin.x, accuracy: 2,
                       "Explore content moved horizontally - the screen is pannable sideways")
    }
}
