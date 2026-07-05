import SwiftUI

/// The Home week scrubber: seven day pills per week, swipeable back through history
/// to the week of the earliest logged day (deep browsing stays in Activity). Tapping
/// a day drives the whole screen's data; today's pill carries the outline ring, and
/// day rollover snaps the pager home overnight.
struct WeekStrip: View {
    /// Today's `yyyy-MM-dd` label.
    let today: String
    /// The selected day label.
    let selected: String
    /// kcal per logged day (any entry > 0 marks the day as logged).
    let dayKcal: [String: Int]
    let onSelect: (String) -> Void

    /// Week-start key of the visible page.
    @State private var visibleWeek = ""

    @Environment(\.dynamicTypeSize) private var typeSize

    private var currentWeekStart: String { DayKey.weekStart(of: today) ?? today }

    private var earliestWeekStart: String {
        guard let firstLogged = dayKcal.keys.min(),
              let start = DayKey.weekStart(of: firstLogged) else { return currentWeekStart }
        return min(start, currentWeekStart)
    }

    private var weeks: [String] { DayKey.weekStarts(from: earliestWeekStart, to: currentWeekStart) }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // At accessibility sizes the pager trades poorly against pill width;
                // fall back to a scrollable current week.
                ScrollView(.horizontal, showsIndicators: false) {
                    weekRow(currentWeekStart)
                }
            } else {
                TabView(selection: $visibleWeek) {
                    ForEach(weeks, id: \.self) { weekStart in
                        weekRow(weekStart).tag(weekStart)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 70)
            }
        }
        .onAppear { syncVisibleWeek() }
        .onChange(of: today) { _, _ in syncVisibleWeek(force: true) }
        .onChange(of: selected) { _, new in
            // External selection changes (day rollover reset) pull the pager along.
            if let week = DayKey.weekStart(of: new), week != visibleWeek {
                visibleWeek = week
            }
        }
    }

    private func syncVisibleWeek(force: Bool = false) {
        if force || visibleWeek.isEmpty || !weeks.contains(visibleWeek) {
            visibleWeek = currentWeekStart
        }
    }

    private func weekRow(_ weekStart: String) -> some View {
        HStack(spacing: Spacing.s) {
            ForEach(0..<7, id: \.self) { offset in
                if let day = DayKey.shifted(weekStart, by: offset) {
                    cell(day)
                }
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
            today: "2026-07-04",
            selected: "2026-07-04",
            dayKcal: ["2026-06-20": 1500, "2026-06-29": 1800, "2026-07-01": 2100, "2026-07-02": 1650],
            onSelect: { _ in }
        )
        .padding(Spacing.screen)
    }
}
