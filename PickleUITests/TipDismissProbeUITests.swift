import XCTest

/// TEMPORARY probe: documents what dismisses a tip after the X-only proxy change.
/// Expected: outside taps and anchor taps leave the tip alone; only the X kills it.
final class TipDismissProbeUITests: XCTestCase {

    @MainActor
    func testTipSurvivesEverythingButX() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "--tips-reset"]
        app.launch()

        let tipText = app.staticTexts["Log anything in seconds"].firstMatch
        XCTAssertTrue(tipText.waitForExistence(timeout: 10), "tip 1 should appear")

        // (a) outside tap
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30)).tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(tipText.exists, "tip died from an OUTSIDE tap")

        // (b) anchor tap (the Log button underneath the proxy)
        let log = app.buttons["Log food"].firstMatch
        if log.isHittable {
            log.tap()
            Thread.sleep(forTimeInterval: 1)
            // Close the Log sheet if it opened.
            let close = app.buttons["Close"].firstMatch
            if close.exists && close.isHittable { close.tap() }
            Thread.sleep(forTimeInterval: 1)
            XCTAssertTrue(tipText.exists, "tip died from tapping its ANCHOR")
        } else {
            NSLog("PROBE: Log button not hittable while tip visible")
        }

        // (c) the X (our own bubble's close button - label is under our control).
        let x = app.buttons["Dismiss tip"].firstMatch
        XCTAssertTrue(x.waitForExistence(timeout: 5), "could not find the tip's X button")
        x.tap()
        let dismissed = true
        XCTAssertTrue(dismissed)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(tipText.exists, "tip should die from the X")

        // Ordered group: next tip appears.
        let tip2 = app.staticTexts["Your day at a glance"].firstMatch
        XCTAssertTrue(tip2.waitForExistence(timeout: 5), "tip 2 should follow after X")
    }
}
