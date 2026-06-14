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

                    group("DAILY FUEL") {
                        DailyFuelCard(consumed: 1150, target: 2200,
                                      protein: (85, 140), carbs: (120, 240), fat: (40, 70),
                                      mealsLogged: 2, mealsTotal: 4)
                    }

                    group("MILESTONE") {
                        MilestoneBanner(title: "3-day streak",
                                        subtitle: "You're building momentum. Keep going.") {}
                    }

                    group("RING + DOTS") {
                        HStack(spacing: Spacing.xxl) {
                            KcalRing(consumed: 1700, target: 2200, diameter: 120)
                            VStack(alignment: .leading, spacing: Spacing.l) {
                                MealDots(logged: 3, total: 4)
                                KcalRing(consumed: 0, target: 2200, diameter: 84, hasData: false)
                            }
                        }
                    }

                    group("CALENDAR DAY STATES") {
                        HStack(spacing: Spacing.l) {
                            CalendarDayCircle(day: 8, state: .goalHit)
                            CalendarDayCircle(day: 9, state: .logged)
                            CalendarDayCircle(day: 11, state: .logged, isToday: true)
                            CalendarDayCircle(day: 12, state: .empty)
                            CalendarDayCircle(day: 20, state: .future)
                        }
                    }

                    group("STATS") {
                        HStack {
                            StatBlock(number: "3", label: "Day streak")
                            StatBlock(number: "12", label: "Days logged")
                            StatBlock(number: "1,980", label: "Avg kcal")
                        }
                    }

                    group("PHOTO CARDS") {
                        HStack(spacing: Spacing.m) {
                            PhotoCard(title: "High Protein", subtitle: "24 meals",
                                      eyebrow: "Collection", seed: 1, height: 180)
                            PhotoCard(title: "Under 500", subtitle: "31 meals",
                                      eyebrow: "Collection", seed: 2, height: 180)
                        }
                    }

                    group("IMAGE ROW") { ImageRow(title: "Club Locations", seed: 4) }

                    group("QUICK LINKS") {
                        VStack(spacing: 0) {
                            QuickLinkRow(title: "Favorites", systemImage: "heart", seed: 5)
                            Divider().overlay(Palette.hairline)
                            QuickLinkRow(title: "Custom Foods", systemImage: "square.and.pencil", seed: 6)
                        }
                    }

                    group("BUTTONS") {
                        VStack(spacing: Spacing.m) {
                            PrimaryButton(title: "Continue") {}
                            SecondaryButton(title: "Create custom food") {}
                            TextLink(title: "Skip for now") {}
                        }
                    }

                    group("INPUTS") {
                        VStack(spacing: Spacing.xl) {
                            UnderlineField(label: "First name", text: $name)
                            UtilityStepper(label: "Calories", value: $kcal, step: 10, unit: "kcal")
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                ValidationRow(text: "One number", satisfied: true)
                                ValidationRow(text: "8 characters minimum", satisfied: false)
                            }
                        }
                    }

                    group("CATEGORY + LOADER") {
                        HStack(spacing: Spacing.m) {
                            CategoryButton(title: "HIIT") {}
                            CategoryButton(title: "Strength") {}
                        }
                        DotLoader().frame(maxWidth: .infinity).padding(.vertical, Spacing.l)
                    }
                }
                .padding(Spacing.screen)
                .padding(.bottom, 120)
            }

            VStack {
                Spacer()
                PickleTabBar(items: PickleTabItem.pickleTabs, selection: $tab)
            }

            FloatingPill { }
                .padding(.trailing, Spacing.l)
                .padding(.bottom, 92)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
            Eyebrow(text: title)
            content()
        }
    }
}

#Preview {
    DesignSystemGallery()
}
