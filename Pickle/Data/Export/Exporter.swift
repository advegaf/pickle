import Foundation

/// Serializes the full diary to CSV or JSON for the "Export my data" feature. Pure string
/// production (unit-tested); the file handling + share sheet live in the More feature.
enum Exporter {

    struct ExportRow: Equatable, Sendable {
        let localDay: String
        let loggedAt: Date
        let meal: String
        let name: String
        let brand: String
        let amount: Double
        let unit: String
        let kcal: Int
        let proteinG: Int
        let carbsG: Int
        let fatG: Int
    }

    static func rows(from days: [DiaryDay]) -> [ExportRow] {
        days.flatMap { day in
            day.entries.map { e in
                ExportRow(localDay: e.localDay, loggedAt: e.loggedAt, meal: e.meal.rawValue,
                          name: e.name, brand: e.brand ?? "", amount: e.amount,
                          unit: e.unit.rawValue, kcal: e.macros.kcal, proteinG: e.macros.proteinG,
                          carbsG: e.macros.carbsG, fatG: e.macros.fatG)
            }
        }
        .sorted { $0.loggedAt < $1.loggedAt }
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func csv(_ rows: [ExportRow]) -> String {
        let header = "date,logged_at,meal,name,brand,amount,unit,kcal,protein_g,carbs_g,fat_g"
        let body = rows.map { r in
            [r.localDay, iso.string(from: r.loggedAt), r.meal, escape(r.name), escape(r.brand),
             trimmed(r.amount), r.unit, "\(r.kcal)", "\(r.proteinG)", "\(r.carbsG)", "\(r.fatG)"]
                .joined(separator: ",")
        }
        return ([header] + body).joined(separator: "\n")
    }

    static func json(_ rows: [ExportRow]) -> String {
        guard !rows.isEmpty else { return "[]" }
        let objects: [[String: Any]] = rows.map { r in
            ["date": r.localDay, "loggedAt": iso.string(from: r.loggedAt), "meal": r.meal,
             "name": r.name, "brand": r.brand, "amount": r.amount, "unit": r.unit,
             "kcal": r.kcal, "proteinG": r.proteinG, "carbsG": r.carbsG, "fatG": r.fatG]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    /// RFC-4180 CSV escaping: wrap in quotes and double internal quotes when needed.
    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    private static func trimmed(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d)
    }
}
