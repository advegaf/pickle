import SwiftUI

/// One day's diary: totals up top, then each meal's logged items. Swipe to delete an entry.
struct DayDetailView: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss
    let localDay: String

    private var day: DiaryDay { store.diaryDay(localDay) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    totals
                    ForEach(MealSlot.allCases) { meal in
                        let entries = day.entries(for: meal)
                        if !entries.isEmpty {
                            mealSection(meal, entries)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.l)
            }
            .background(Palette.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.primary)
                }
            }
        }
        .presentationBackground(Palette.background)
    }

    private var totals: some View {
        let t = day.totals
        return VStack(spacing: Spacing.l) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(t.kcal)")
                    .font(PickleFont.stat(44)).foregroundStyle(Palette.primary).monospacedDigit()
                Text("kcal").font(PickleFont.body()).foregroundStyle(Palette.tertiary)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: Spacing.xl) {
                macroStat("Protein", t.proteinG)
                macroStat("Carbs", t.carbsG)
                macroStat("Fat", t.fatG)
            }
        }
        .padding(Spacing.l)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private func macroStat(_ label: String, _ grams: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(grams)g").font(PickleFont.bodyMedium(17)).foregroundStyle(Palette.primary).monospacedDigit()
            Text(label).font(PickleFont.caption(11)).foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func mealSection(_ meal: MealSlot, _ entries: [LoggedFood]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Eyebrow(text: meal.title)
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name).font(PickleFont.bodyMedium(15)).foregroundStyle(Palette.primary)
                            Text(portionLabel(entry)).font(PickleFont.caption(12)).foregroundStyle(Palette.tertiary)
                        }
                        Spacer()
                        Text("\(entry.macros.kcal) kcal")
                            .font(PickleFont.caption()).foregroundStyle(Palette.secondary).monospacedDigit()
                        Button { store.deleteLog(id: entry.id); Haptics.select() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.tertiary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.pressable)
                    }
                    .frame(minHeight: 48)
                    Divider().overlay(Palette.hairline)
                }
            }
        }
    }

    private func portionLabel(_ e: LoggedFood) -> String {
        let amt = e.amount == e.amount.rounded() ? String(Int(e.amount)) : String(format: "%.1f", e.amount)
        return "\(amt) \(e.unit.abbreviation)"
    }

    private var title: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; f.timeZone = .current
        let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd"; p.timeZone = .current
        return p.date(from: localDay).map { f.string(from: $0) } ?? "Day"
    }
}
