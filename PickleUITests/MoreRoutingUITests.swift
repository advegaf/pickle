import XCTest

/// Reproduces and guards the More-tab routing: tapping each row must open ITS destination, not a
/// neighbour. Taps by the row's accessibility identifier (now reliable since `ListRow` is a clean
/// Button with a correct hit/accessibility frame, unlike the old `Color.clear`-backed image row).
final class MoreRoutingUITests: XCTestCase {

    private let order = ["goals", "health", "favorites", "custom", "loved", "export", "about"]

    override func setUp() { continueAfterFailure = true }

    func testEachMoreRowOpensItsOwnDestination() {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "--tab", "4"]
        app.launch()

        XCTAssertTrue(app.staticTexts["More"].waitForExistence(timeout: 20), "More tab never appeared")

        var mismatches: [String] = []

        for expected in order {
            let row = app.descendants(matching: .any)["more-row-\(expected)"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "row \(expected) missing")
            if !row.isHittable { app.swipeUp() }
            row.tap()

            _ = app.descendants(matching: .any)["more-dest-\(expected)"].firstMatch.waitForExistence(timeout: 4)
            let actualDest = order.first { app.descendants(matching: .any)["more-dest-\($0)"].firstMatch.exists } ?? "none"
            if actualDest != expected {
                mismatches.append("\(expected) -> \(actualDest)")
            }

            let done = app.buttons["Done"].firstMatch
            let cancel = app.buttons["Cancel"].firstMatch
            if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
            else if cancel.exists, cancel.isHittable { cancel.tap() }
            else { app.swipeDown() }

            _ = app.staticTexts["More"].waitForExistence(timeout: 5)
        }

        XCTAssertTrue(mismatches.isEmpty,
                      "More rows route to the WRONG destination: \(mismatches.joined(separator: ", "))")
    }
}
