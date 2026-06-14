import Foundation

/// Writes an export to an app-private temp file for the share sheet, excluded from iCloud
/// backup. The OS reclaims the temp directory; we also remove prior exports first.
enum ExportFile {
    enum Format { case csv, json }

    static func write(days: [DiaryDay], format: Format) -> URL? {
        let rows = Exporter.rows(from: days)
        let contents = format == .csv ? Exporter.csv(rows) : Exporter.json(rows)
        let ext = format == .csv ? "csv" : "json"
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pickle-export", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var url = dir.appendingPathComponent("pickle-diary.\(ext)")
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
            return url
        } catch {
            return nil
        }
    }
}
