import SwiftUI

/// Debug-only catalog of every design-system component on the black canvas. Used for the
/// visual-fidelity loop against the reference frames. Not shipped in any user flow.
struct DesignSystemGallery: View {
    @State private var name = ""
    @State private var kcal = 250
    @State private var tab = 0

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    header

                    group("Arc gauge (Whoop ramp)") {
                        VStack(spacing: Spacing.xl) {
                            ArcGauge(consumed: 300, target: 2000, diameter: 160)   // green zone
                            ArcGauge(consumed: 1023, target: 2000, diameter: 200)  // yellow zone
                            ArcGauge(consumed: 1840, target: 2000, diameter: 160)  // orange, near goal
                            ArcGauge(consumed: 2134, target: 2000, diameter: 160)  // Whoop red, over
                            ArcGauge(consumed: 0, target: 2000, diameter: 160, isEmptyDay: true)
                            ArcGauge(consumed: 0, target: 0, diameter: 160, hasData: false)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    group("Macro cards") {
                        MacroCardRow(
                            consumed: MacroTargets(kcal: 1023, proteinG: 86, carbsG: 142, fatG: 41),
                            targets: MacroTargets(kcal: 2000, proteinG: 180, carbsG: 220, fatG: 70)
                        )
                    }

                    group("Week strip") {
                        WeekStrip(
                            today: "2026-07-03",
                            selected: "2026-07-03",
                            dayKcal: ["2026-06-29": 1800, "2026-07-01": 2100, "2026-07-02": 1650],
                            onSelect: { _ in }
                        )
                    }

                    group("Chips") {
                        HStack(spacing: Spacing.m) {
                            StreakChip(streak: 13)
                            StreakChip(streak: 0)
                            BellChip(missed: 2) {}
                            BellChip(missed: 0) {}
                        }
                        HStack(spacing: Spacing.m) {
                            MacroChip(value: "180g", label: "Protein", tint: Palette.protein)
                            MacroChip(value: "220g", label: "Carbs", tint: Palette.carbs)
                            MacroChip(value: "70g", label: "Fat", tint: Palette.fat)
                        }
                    }

                    group("Macro bars") {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            MacroBar(label: "Protein", short: "P", value: 85, target: 140, tint: Palette.protein)
                            MacroBar(label: "Carbs", short: "C", value: 120, target: 240, tint: Palette.carbs)
                            MacroBar(label: "Fat", short: "F", value: 40, target: 70, tint: Palette.fat)
                        }
                        MacroLine(macros: MacroTargets(kcal: 520, proteinG: 30, carbsG: 40, fatG: 20))
                    }

                    group("Calendar day states") {
                        HStack(spacing: Spacing.l) {
                            CalendarDayCircle(day: 8, state: .goalHit)
                            CalendarDayCircle(day: 9, state: .logged)
                            CalendarDayCircle(day: 11, state: .logged, isToday: true)
                            CalendarDayCircle(day: 12, state: .empty)
                            CalendarDayCircle(day: 20, state: .future)
                        }
                    }

                    group("Stats") {
                        HStack {
                            StatBlock(number: "3", label: "Day streak")
                            StatBlock(number: "12", label: "Days logged")
                            StatBlock(number: "1,980", label: "Avg cal")
                        }
                    }

                    group("Photo cards") {
                        HStack(spacing: Spacing.m) {
                            PhotoCard(title: "High Protein", subtitle: "24 meals",
                                      eyebrow: "Collection", seed: 1, height: 180)
                            PhotoCard(title: "Under 500", subtitle: "31 meals",
                                      eyebrow: "Collection", seed: 2, height: 180)
                        }
                    }

                    group("Grouped list") {
                        GroupedListCard {
                            ListRow(icon: .favorite, title: "Favorites")
                            ListRowDivider()
                            ListRow(icon: .edit, title: "Custom Foods")
                        }
                    }

                    group("Buttons") {
                        VStack(spacing: Spacing.m) {
                            PrimaryButton(title: "Continue") {}
                            SecondaryButton(title: "Create custom food") {}
                            TextLink(title: "Skip for now") {}
                        }
                    }

                    group("Inputs") {
                        VStack(spacing: Spacing.xl) {
                            UnderlineField(label: "First name", text: $name)
                            UtilityStepper(label: "Calories", value: $kcal, step: 10, unit: "cal")
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                ValidationRow(text: "One number", satisfied: true)
                                ValidationRow(text: "8 characters minimum", satisfied: false)
                            }
                        }
                    }

                    group("Category + loader") {
                        HStack(spacing: Spacing.m) {
                            CategoryButton(title: "HIIT") {}
                            CategoryButton(title: "Strength") {}
                        }
                        DotLoader().frame(maxWidth: .infinity).padding(.vertical, Spacing.l)
                    }
                }
                .padding(Spacing.screen)
                .padding(.bottom, Spacing.l)
            }

            VStack {
                Spacer()
                FloatingTabBar(items: PickleTabItem.pickleTabs, selection: $tab) {}
                    .padding(.horizontal, Spacing.screen + 4)
                    .padding(.bottom, Spacing.s)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("What will you fuel today?")
                .font(PickleFont.display(32))
                .foregroundStyle(Palette.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Design system")
                .font(PickleFont.caption())
                .foregroundStyle(Palette.tertiary)
        }
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: title)
            content()
        }
    }
}

#Preview {
    DesignSystemGallery()
}
