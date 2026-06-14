import SwiftUI

/// A month grid of `CalendarDayCircle`s. Day state comes from the diary: not-logged,
/// logged-but-missed-goal, logged + goal hit, today, or upcoming.
struct MonthCalendar: View {
    let monthAnchor: Date
    let kcalByDay: [String: Int]
    let targetKcal: Int
    let today: String
    let onSelectDay: (String) -> Void
    let onShiftMonth: (Int) -> Void

    private let cal = Calendar(identifier: .gregorian)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: Spacing.m) {
            header
            weekdayRow
            grid
        }
    }

    private var header: some View {
        HStack {
            Text(monthTitle)
                .font(PickleFont.heading(20))
                .foregroundStyle(Palette.primary)
            Spacer()
            HStack(spacing: Spacing.l) {
                navButton("chevron.left") { onShiftMonth(-1) }
                navButton("chevron.right") { onShiftMonth(1) }
            }
        }
    }

    private func navButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.pressable)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(PickleFont.eyebrow(11))
                    .foregroundStyle(Palette.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let cells = dayCells()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    let key = dayKey(day)
                    CalendarDayCircle(day: day, state: state(for: key), isToday: key == today)
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            if kcalByDay[key] != nil { onSelectDay(key); Haptics.select() }
                        }
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    // MARK: - Date math

    private var components: DateComponents { cal.dateComponents([.year, .month], from: monthAnchor) }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM, yyyy"
        return f.string(from: monthAnchor)
    }

    /// Cells for the grid: leading nils for the offset to the first weekday (Mon-based), then days.
    private func dayCells() -> [Int?] {
        guard let firstOfMonth = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth) // 1=Sun...7=Sat
        let mondayOffset = (weekdayOfFirst + 5) % 7 // convert to Mon=0
        var cells: [Int?] = Array(repeating: nil, count: mondayOffset)
        cells += range.map { Optional($0) }
        return cells
    }

    private func dayKey(_ day: Int) -> String {
        var c = components
        c.day = day
        guard let date = cal.date(from: c) else { return "" }
        return DayKey.localDay(for: date)
    }

    private func state(for key: String) -> CalendarDayCircle.DayState {
        guard let ord = DayKey.ordinal(key), let todayOrd = DayKey.ordinal(today) else { return .future }
        if ord > todayOrd { return .future }
        if let kcal = kcalByDay[key], kcal > 0 {
            let withinGoal = abs(kcal - targetKcal) <= Int(Double(targetKcal) * 0.1)
            return withinGoal ? .goalHit : .logged
        }
        return .empty
    }
}
