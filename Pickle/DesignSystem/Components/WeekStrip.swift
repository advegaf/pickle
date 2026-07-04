import SwiftUI

/// The Home week scrubber: the current week's seven day pills. Tapping a day drives
/// the whole screen's data (gauge, macros, meals) for that day. Deep history stays in
/// Activity; this is a 7-day quick scrubber, not a calendar.
struct WeekStrip: View {
    /// Today's `yyyy-MM-dd` label.
    let today: String
    /// The selected day label.
    let selected: String
    /// kcal per logged day (any entry > 0 marks the day as logged).
    let dayKcal: [String: Int]
    let onSelect: (String) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var week: [String] {
        guard let start = DayKey.weekStart(of: today) else { return [] }
        return (0..<7).compactMap { DayKey.shifted(start, by: $0) }
    }

    var body: some View {
        let cells = HStack(spacing: Spacing.s) {
            ForEach(week, id: \.self) { day in
                cell(day)
            }
        }
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView(.horizontal, showsIndicators: false) { cells }
            } else {
                cells
            }
        }
    }

    private func cell(_ day: String) -> some View {
        let isToday = day == today
        let isSelected = day == selected
        let isFuture = (DayKey.ordinal(day) ?? 0) > (DayKey.ordinal(today) ?? 0)
        let kcal = dayKcal[day] ?? 0
        let logged = kcal > 0

        return Button {
            if !isSelected { onSelect(day); Haptics.select() }
        } label: {
            VStack(spacing: 3) {
                Text(weekdayLetter(day))
                    .font(PickleFont.caption(11))
                    .foregroundStyle(isSelected ? Palette.onAccent.opacity(0.7) : Palette.tertiary)
                Text(dayNumber(day))
                    .font(PickleFont.bodyMedium(15))
                    .foregroundStyle(isSelected ? Palette.onAccent : Palette.primary)
                    .monospacedDigit()
                Circle()
                    .fill(logged && !isSelected ? Palette.tertiary : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                Capsule().fill(isSelected ? Color.white : Palette.surface)
            )
            .overlay(
                Capsule().strokeBorder(
                    isToday && !isSelected ? Palette.primary.opacity(0.7) : Palette.glassEdge,
                    lineWidth: 1
                )
            )
            .opacity(isFuture ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText(day, kcal: kcal, logged: logged, isFuture: isFuture))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func weekdayLetter(_ day: String) -> String {
        guard let wd = DayKey.weekday(day) else { return "" }
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols[(wd - 1) % 7]
    }

    private func dayNumber(_ day: String) -> String {
        String(Int(day.suffix(2)) ?? 0)
    }

    private func accessibilityText(_ day: String, kcal: Int, logged: Bool, isFuture: Bool) -> String {
        let name: String
        if let wd = DayKey.weekday(day) {
            name = Calendar.current.weekdaySymbols[(wd - 1) % 7]
        } else {
            name = ""
        }
        let number = dayNumber(day)
        if isFuture { return "\(name) \(number), upcoming" }
        if day == today && !logged { return "\(name) \(number), today, nothing logged yet" }
        if logged { return "\(name) \(number), \(kcal) calories logged" }
        return "\(name) \(number), nothing logged"
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        WeekStrip(
            today: "2026-07-03",
            selected: "2026-07-03",
            dayKcal: ["2026-06-29": 1800, "2026-07-01": 2100, "2026-07-02": 1650],
            onSelect: { _ in }
        )
        .padding(Spacing.screen)
    }
}
