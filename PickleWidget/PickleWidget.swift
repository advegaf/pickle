import WidgetKit
import SwiftUI

// Local palette (the app's Tokens live in the app target; the widget keeps its own minimal set).
private enum W {
    static let bg = Color.black
    static let primary = Color.white
    static let secondary = Color(.sRGB, white: 0.64, opacity: 1)   // ~#A3A3A3
    static let tertiary = Color(.sRGB, white: 0.54, opacity: 1)    // ~#8A8A8A
    static let faint = Color(.sRGB, white: 0.36, opacity: 1)
    static let protein = Color(.sRGB, red: 0.91, green: 0.89, blue: 0.83, opacity: 1)
    static let carbs = Color(.sRGB, red: 0.79, green: 0.76, blue: 0.69, opacity: 1)
    static let fat = Color(.sRGB, red: 0.69, green: 0.66, blue: 0.56, opacity: 1)
}

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

// MARK: - Views

struct KcalRingMini: View {
    let fraction: Double
    let lineWidth: CGFloat
    var over: Bool = false

    var body: some View {
        ZStack {
            Circle().stroke(W.faint.opacity(0.4), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(over ? W.tertiary : W.primary,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct MacroBarMini: View {
    let short: String
    let value: Int
    let target: Int
    let tint: Color

    private var fraction: Double { target > 0 ? min(Double(value) / Double(target), 1) : 0 }

    var body: some View {
        HStack(spacing: 5) {
            Text(short).font(.system(size: 9, weight: .medium)).foregroundStyle(W.tertiary).frame(width: 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(W.faint.opacity(0.35))
                    Capsule().fill(tint).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 3)
        }
    }
}

struct PickleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PickleEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        default: homeWidget
        }
    }

    private var snap: DiarySnapshot { entry.snapshot }

    private var circular: some View {
        ZStack {
            KcalRingMini(fraction: snap.fraction, lineWidth: 5, over: snap.consumedKcal > snap.targetKcal)
            VStack(spacing: 0) {
                Text("\(snap.remainingKcal)")
                    .font(.system(size: 17, weight: .bold)).monospacedDigit()
                Text("left").font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var homeWidget: some View {
        HStack(spacing: 14) {
            ZStack {
                KcalRingMini(fraction: snap.fraction, lineWidth: 8, over: snap.consumedKcal > snap.targetKcal)
                VStack(spacing: 0) {
                    Text("\(snap.remainingKcal)")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(W.primary).monospacedDigit()
                    Text("LEFT").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(W.tertiary)
                }
            }
            .frame(width: 92, height: 92)

            if family != .systemSmall {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DAILY FUEL").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(W.tertiary)
                    MacroBarMini(short: "P", value: snap.proteinG, target: snap.proteinTarget, tint: W.protein)
                    MacroBarMini(short: "C", value: snap.carbsG, target: snap.carbsTarget, tint: W.carbs)
                    MacroBarMini(short: "F", value: snap.fatG, target: snap.fatTarget, tint: W.fat)
                    Text("\(snap.consumedKcal) / \(snap.targetKcal) kcal")
                        .font(.system(size: 11)).foregroundStyle(W.secondary).monospacedDigit()
                }
            }
        }
        .padding(family == .systemSmall ? 4 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(W.bg, for: .widget)
        .widgetURL(URL(string: "pickle://log"))
    }
}

struct PickleWidget: Widget {
    let kind = "PickleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PickleProvider()) { entry in
            PickleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Calories Remaining")
        .description("Your calories left and macros for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
