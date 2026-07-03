import WidgetKit
import SwiftUI

/// A second, macro-first widget for people who track protein/carbs/fat before calories. Reuses
/// the same App-Group snapshot + provider as the calorie widget, so both stay in sync.
struct PickleMacrosWidget: Widget {
    let kind = "PickleMacrosWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PickleProvider()) { entry in
            MacrosEntryView(entry: entry)
        }
        .configurationDisplayName("Macros")
        .description("Today's protein, carbs, and fat.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct MacrosEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PickleEntry

    var body: some View {
        switch family {
        case .accessoryCircular: MacrosCircular(snap: snap).containerBackground(.clear, for: .widget)
        case .accessoryRectangular: MacrosRectangular(snap: snap).containerBackground(.clear, for: .widget)
        default: MacrosHome(snap: snap, small: family == .systemSmall)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(W.bg, for: .widget)
            .widgetURL(URL(string: "pickle://log"))
        }
    }

    private var snap: DiarySnapshot { entry.snapshot }
}
