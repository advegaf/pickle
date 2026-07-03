import WidgetKit
import SwiftUI

// The W palette + every family view live in Shared/WidgetViews.swift (compiled into both the
// widget and the app, so the app's DEBUG gallery renders the exact same layouts). This file
// holds the timeline plumbing and the "Calories Remaining" widget configuration.

struct PickleEntry: TimelineEntry {
    let date: Date
    let snapshot: DiarySnapshot
}

struct PickleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PickleEntry {
        PickleEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PickleEntry) -> Void) {
        completion(PickleEntry(date: Date(), snapshot: current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PickleEntry>) -> Void) {
        let now = Date()
        let snap = current()
        var entries = [PickleEntry(date: now, snapshot: snap)]

        // Self-zero at the next local midnight, preserving the day's targets.
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .nextTime) {
            let emptyDay = DiarySnapshot.empty(localDay: "", target: snap)
            entries.append(PickleEntry(date: midnight, snapshot: emptyDay))
            completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
        } else {
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private func current() -> DiarySnapshot {
        DiarySnapshotStore.read() ?? .placeholder
    }
}

// MARK: - Calories Remaining widget

struct PickleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PickleEntry

    var body: some View {
        switch family {
        case .accessoryCircular: CalorieCircular(snap: snap).containerBackground(.clear, for: .widget)
        case .accessoryRectangular: CalorieRectangular(snap: snap).containerBackground(.clear, for: .widget)
        case .accessoryInline: CalorieInline(snap: snap).containerBackground(.clear, for: .widget)
        case .systemLarge:
            CalorieLarge(snap: snap)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(W.bg, for: .widget)
                .widgetURL(URL(string: "pickle://log"))
        default:
            CalorieHome(snap: snap, small: family == .systemSmall)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(W.bg, for: .widget)
                .widgetURL(URL(string: "pickle://log"))
        }
    }

    private var snap: DiarySnapshot { entry.snapshot }
}

struct PickleWidget: Widget {
    let kind = "PickleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PickleProvider()) { entry in
            PickleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Calories Remaining")
        .description("Your calories left and macros for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
