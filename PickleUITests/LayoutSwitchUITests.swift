import XCTest

/// Guards the Home layout picker: choosing a tile in Profile must rearrange the Home
/// hero LIVE (regression: writes through one UserDefaults suite instance were not
/// observed by another, so the switch only appeared after an app relaunch).
final class LayoutSwitchUITests: XCTestCase {

    @MainActor
    func testPickingLayoutRearrangesHomeLive() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed", "--no-tips"]
        app.launch()

        let protein = app.staticTexts["Protein"].firstMatch
        XCTAssertTrue(protein.waitForExistence(timeout: 10))
        let before = protein.frame

        // Open Profile, flip to whichever layout is not currently selected.
        app.buttons["Your profile"].firstMatch.tap()
        let side = app.buttons["Side by side layout"].firstMatch
        XCTAssertTrue(side.waitForExistence(timeout: 8))
        app.swipeUp()

        let sideSelected = side.isSelected
        (sideSelected ? app.buttons["Stacked layout"] : side).firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()

        // The hero must have rearranged without a relaunch.
        Thread.sleep(forTimeInterval: 1.0)
        let after = protein.frame
        XCTAssertGreaterThan(abs(after.minY - before.minY) + abs(after.minX - before.minX), 30,
                             "Home hero did not rearrange after picking the other layout (before \(before), after \(after))")
    }
}
