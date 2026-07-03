import Foundation

/// The north-star metric, made visible: seconds from opening the Log sheet to a saved
/// diary entry. Rolling last-50 samples in App Group defaults; surfaced as a median in
/// the DEBUG row of About. Ten lines that turn "logging feels fast" into a number.
enum LogMetric {
    private static let key = "pickle.metrics.secondsToLog"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: DiarySnapshotStore.appGroup) ?? .standard
    }

    static func record(from start: Date, now: Date = Date()) {
        var samples = (defaults.array(forKey: key) as? [Double]) ?? []
        samples.append(now.timeIntervalSince(start))
        if samples.count > 50 { samples.removeFirst(samples.count - 50) }
        defaults.set(samples, forKey: key)
    }

    static var median: Double? {
        let samples = ((defaults.array(forKey: key) as? [Double]) ?? []).sorted()
        guard !samples.isEmpty else { return nil }
        return samples[samples.count / 2]
    }

    static var sampleCount: Int {
        ((defaults.array(forKey: key) as? [Double]) ?? []).count
    }

    static func reset() {
        defaults.removeObject(forKey: key)
    }
}
