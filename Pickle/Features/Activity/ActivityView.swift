import SwiftUI

/// Activity: the month calendar, stats, and your logged-day history. Tap a day for its detail.
struct ActivityView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var monthAnchor = Date()
    @State private var selectedDay: String?
    @State private var showAddWeight = false

    private var stats: ActivityStats { store.activityStats() }
    private var kcalByDay: [String: Int] { store.dailyKcal() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header

                MonthCalendar(
                    monthAnchor: monthAnchor,
                    kcalByDay: kcalByDay,
                    targetKcal: store.profile().targets.kcal,
                    today: store.todayKey(),
                    onSelectDay: { selectedDay = $0 },
                    onShiftMonth: { shiftMonth($0) }
                )
                legend
                Divider().overlay(Palette.hairline)
                statsRow
                insights
                activeDays
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .background(Palette.background)
        .sheet(isPresented: $showAddWeight) {
            AddWeightSheet { kg in store.addWeight(kg: kg) }
        }
        .sheet(item: Binding(get: { selectedDay.map { DayRef(day: $0) } },
                             set: { selectedDay = $0?.day })) { ref in
            DayDetailView(localDay: ref.day)
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack {
            Text("Activity")
                .font(PickleFont.display(34))
                .foregroundStyle(Palette.primary)
            Spacer()
            Button { showAddWeight = true } label: {
                HStack(spacing: 5) {
                    PickleIcon(.add, size: 14)
                    Text("Weight").font(PickleFont.button(14))
                }
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, Spacing.m)
                .frame(height: 40)
                .overlay(Capsule().stroke(Palette.hairline, lineWidth: 1))
            }
            .buttonStyle(.pressable)
        }
    }

    private var legend: some View {
        HStack(spacing: Spacing.l) {
            legendItem(.goalHit, "Goal met")
            legendItem(.logged, "Logged")
            legendItem(.empty, "Missed")
            Spacer()
        }
        .padding(.top, Spacing.xs)
    }

    private func legendItem(_ state: CalendarDayCircle.DayState, _ label: String) -> some View {
        HStack(spacing: 6) {
            CalendarDayCircle(day: 0, state: state, size: 14)
                .frame(width: 14, height: 14)
            Text(label).font(PickleFont.caption(11)).foregroundStyle(Palette.tertiary)
        }
    }

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Your stats")
            HStack {
                StatBlock(number: "\(stats.streak)", label: "Day streak")
                StatBlock(number: "\(stats.daysLogged)", label: "Days logged")
                StatBlock(number: stats.avgKcal > 0 ? "\(stats.avgKcal)" : "-", label: "Avg cal")
            }
        }
    }

    @ViewBuilder private var insights: some View {
        if stats.daysLogged < 7 {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionLabel(text: "Insights")
                Text("Keep logging, after 7 days, Pickle starts surfacing trends and refining your plan.")
                    .font(PickleFont.body(14))
                    .foregroundStyle(Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var activeDays: some View {
        let days = store.activeDays()
        return VStack(alignment: .leading, spacing: Spacing.m) {
            if !days.isEmpty {
                SectionLabel(text: "Active days")
                VStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        Button { selectedDay = day } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(longDate(day))
                                        .font(PickleFont.bodyMedium(16))
                                        .foregroundStyle(Palette.primary)
                                    Text("\(kcalByDay[day] ?? 0) cal logged")
                                        .font(PickleFont.caption())
                                        .foregroundStyle(Palette.tertiary)
                                        .monospacedDigit()
                                }
                                Spacer()
                                PickleIcon(.chevronRight, size: 13)
                                    .foregroundStyle(Palette.tertiary)
                            }
                            .frame(minHeight: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        Divider().overlay(Palette.hairline)
                    }
                }
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = next
            Haptics.select()
        }
    }

    private func longDate(_ key: String) -> String {
        guard let date = parse(key) else { return key }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private func parse(_ key: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: key)
    }
}

private struct DayRef: Identifiable { let day: String; var id: String { day } }

/// Simple weight-entry sheet.
struct AddWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Double) -> Void
    @State private var lb = 180

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: Spacing.xl) {
                Text("Log weight")
                    .font(PickleFont.heading(22)).foregroundStyle(Palette.primary)
                UtilityStepper(label: "Weight", value: $lb, step: 1, range: 50...600, unit: "lb")
                PrimaryButton(title: "Save") {
                    onSave(Double(lb) / 2.2046226)
                    Haptics.confirm()
                    dismiss()
                }
            }
            .padding(Spacing.screen)
        }
        .presentationDetents([.height(280)])
        .presentationBackground(Palette.background)
    }
}
