import Foundation

/// Compiled into BOTH the app and the widget. The app writes this small snapshot to the
/// shared App Group container on every diary change; the widget reads it — so the widget
/// never touches SwiftData/CloudKit (no battery cost, no heavy extension work).
struct DiarySnapshot: Codable, Equatable, Sendable {
    var localDay: String
    var updatedAt: Date
    var consumedKcal: Int
    var targetKcal: Int
    var proteinG: Int
    var proteinTarget: Int
    var carbsG: Int
    var carbsTarget: Int
    var fatG: Int
    var fatTarget: Int
    var mealsLogged: Int
    var mealsTotal: Int

    var remainingKcal: Int { max(targetKcal - consumedKcal, 0) }
    var fraction: Double { targetKcal > 0 ? min(Double(consumedKcal) / Double(targetKcal), 1) : 0 }

    /// An empty day for `localDay` — what the widget shows after the midnight rollover.
    static func empty(localDay: String, target: DiarySnapshot? = nil) -> DiarySnapshot {
        DiarySnapshot(localDay: localDay, updatedAt: Date(),
                      consumedKcal: 0, targetKcal: target?.targetKcal ?? 2000,
                      proteinG: 0, proteinTarget: target?.proteinTarget ?? 150,
                      carbsG: 0, carbsTarget: target?.carbsTarget ?? 200,
                      fatG: 0, fatTarget: target?.fatTarget ?? 67,
                      mealsLogged: 0, mealsTotal: 4)
    }

    static let placeholder = DiarySnapshot(
        localDay: "", updatedAt: Date(),
        consumedKcal: 1150, targetKcal: 2200,
        proteinG: 85, proteinTarget: 140, carbsG: 120, carbsTarget: 240, fatG: 40, fatTarget: 70,
        mealsLogged: 2, mealsTotal: 4)
}

/// Reads/writes the snapshot in the shared App Group container.
enum DiarySnapshotStore {
    static let appGroup = "group.com.pickle.tracker"
    static let filename = "diary-snapshot.json"

    static func fileURL(appGroup: String = appGroup) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(filename)
    }

    static func write(_ snapshot: DiarySnapshot, appGroup: String = appGroup) {
        guard let url = fileURL(appGroup: appGroup) else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Pickle: failed to write diary snapshot: \(error)")
        }
    }

    static func read(appGroup: String = appGroup) -> DiarySnapshot? {
        guard let url = fileURL(appGroup: appGroup),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DiarySnapshot.self, from: data)
    }
}
