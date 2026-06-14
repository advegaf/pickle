import WidgetKit
import SwiftUI

// Phase 1 placeholder widget. The real kcal-ring + macro-bar timeline reading the
// App Group DiarySnapshot is built in Phase 12.

struct PickleEntry: TimelineEntry {
    let date: Date
    let kcalRemaining: Int
    let kcalTarget: Int
}

struct PickleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PickleEntry {
        PickleEntry(date: Date(), kcalRemaining: 1050, kcalTarget: 2200)
    }

    func getSnapshot(in context: Context, completion: @escaping (PickleEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PickleEntry>) -> Void) {
        let entry = placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct PickleWidgetEntryView: View {
    var entry: PickleEntry

    var body: some View {
        VStack(spacing: 2) {
            Text("\(entry.kcalRemaining)")
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
            Text("kcal left")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .containerBackground(.black, for: .widget)
        .foregroundStyle(.white)
    }
}

struct PickleWidget: Widget {
    let kind = "PickleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PickleProvider()) { entry in
            PickleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pickle")
        .description("Calories remaining today.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
