import XCTest
@testable import Pickle

final class ExporterTests: XCTestCase {

    private func day(_ localDay: String, _ entries: [LoggedFood]) -> DiaryDay {
        DiaryDay(localDay: localDay, entries: entries)
    }

    private func entry(_ name: String, brand: String? = nil, kcal: Int = 100,
                       at: TimeInterval = 0, meal: MealSlot = .lunch) -> LoggedFood {
        LoggedFood(id: UUID(), loggedAt: Date(timeIntervalSince1970: at), localDay: "2026-06-14",
                   meal: meal, name: name, brand: brand, canonicalID: "x", amount: 1, unit: .serving,
                   macros: MacroTargets(kcal: kcal, proteinG: 5, carbsG: 10, fatG: 3))
    }

    func testCSV_headerAndRowCount() {
        let rows = Exporter.rows(from: [day("2026-06-14", [entry("Banana"), entry("Toast")])])
        let csv = Exporter.csv(rows)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 3) // header + 2 rows
        XCTAssertTrue(lines[0].hasPrefix("date,logged_at,meal,name"))
    }

    func testCSV_escapesCommasAndQuotes() {
        let rows = Exporter.rows(from: [day("2026-06-14", [entry("Rice, white", brand: "Ben's \"Original\"")])])
        let csv = Exporter.csv(rows)
        XCTAssertTrue(csv.contains("\"Rice, white\""))
        XCTAssertTrue(csv.contains("\"Ben's \"\"Original\"\"\""))
    }

    func testRows_sortedByLoggedAt() {
        let rows = Exporter.rows(from: [day("2026-06-14", [
            entry("Late", at: 200), entry("Early", at: 100)
        ])])
        XCTAssertEqual(rows.map(\.name), ["Early", "Late"])
    }

    func testJSON_isValidAndRoundTrips() {
        let rows = Exporter.rows(from: [day("2026-06-14", [entry("Banana", kcal: 89)])])
        let json = Exporter.json(rows)
        let data = json.data(using: .utf8)!
        let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        XCTAssertEqual(parsed?.first?["name"] as? String, "Banana")
        XCTAssertEqual(parsed?.first?["kcal"] as? Int, 89)
    }

    func testEmptyExport_isHeaderOnlyCSV_andEmptyJSONArray() {
        let rows = Exporter.rows(from: [])
        XCTAssertEqual(Exporter.csv(rows).split(separator: "\n").count, 1)
        XCTAssertEqual(Exporter.json(rows), "[]")
    }
}
