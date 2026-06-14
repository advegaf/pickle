import SwiftUI

/// The data-forward Home. The kcal-remaining ring leads; the editorial headline is large on
/// the first-run empty state and recedes to a quiet greeting once the day has data.
struct HomeView: View {
    @EnvironmentObject private var store: PickleStore
    var onLog: () -> Void = {}
    var onLogMeal: (MealSlot) -> Void = { _ in }

    private var profile: ProfileData { store.profile() }
    private var day: DiaryDay { store.today() }
    private var streak: Int {
        StreakCalculator.currentStreak(loggedDays: store.loggedDays(), today: store.todayKey())
    }
    private var firstRun: Bool { day.isEmpty }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header

                    if firstRun {
                        Text("What will you\nfuel today?")
                            .font(PickleFont.display(34))
                            .foregroundStyle(Palette.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    } else {
                        Text(greeting)
                            .font(PickleFont.bodyMedium(17))
                            .foregroundStyle(Palette.secondary)
                    }

                    DailyFuelCard(
                        consumed: day.totals.kcal,
                        target: profile.targets.kcal,
                        protein: (day.totals.proteinG, profile.targets.proteinG),
                        carbs: (day.totals.carbsG, profile.targets.carbsG),
                        fat: (day.totals.fatG, profile.targets.fatG),
                        mealsLogged: day.loggedMealCount,
                        mealsTotal: MealSlot.allCases.count
                    )

                    if streak >= 3 {
                        MilestoneBanner(title: "\(streak)-day streak",
                                        subtitle: "You're building real momentum. Keep it going.")
                    }

                    if firstRun {
                        firstRunHint
                    }

                    mealsSection
                    quickLinks
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.s)
                .padding(.bottom, 140)
            }

            FloatingPill(action: onLog)
                .padding(.trailing, Spacing.l)
                .padding(.bottom, 96)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                Circle().stroke(Palette.hairline, lineWidth: 1).frame(width: 40, height: 40)
                Text(initials)
                    .font(PickleFont.eyebrow(13))
                    .foregroundStyle(Palette.primary)
            }
            Spacer()
            Button(action: onLog) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Palette.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Search foods")
        }
    }

    private var firstRunHint: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.tertiary)
            Text("Log your first meal to begin your day.")
                .font(PickleFont.body(15))
                .foregroundStyle(Palette.secondary)
        }
        .padding(.vertical, Spacing.s)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Today's meals")
            VStack(spacing: Spacing.m) {
                ForEach(MealSlot.allCases) { meal in
                    MealCard(meal: meal,
                             entries: day.entries(for: meal),
                             onAdd: { onLogMeal(meal) })
                }
            }
        }
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Quick links")
            VStack(spacing: 0) {
                QuickLinkRow(title: "Favorites", systemImage: "heart", seed: 11)
                Divider().overlay(Palette.hairline)
                QuickLinkRow(title: "Custom Foods", systemImage: "square.and.pencil", seed: 12)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        let name = profile.name.isEmpty ? "" : ", \(profile.name)"
        return "\(part)\(name)"
    }

    private var initials: String {
        let parts = profile.name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "P" : letters.uppercased()
    }
}

/// Data-forward meal card: meal name + big kcal numeral + macro line. Tappable to log.
struct MealCard: View {
    let meal: MealSlot
    let entries: [LoggedFood]
    let onAdd: () -> Void

    private var totals: MacroTargets { entries.reduce(.zero) { $0 + $1.macros } }
    private var isEmpty: Bool { entries.isEmpty }

    var body: some View {
        Button(action: onAdd) {
            HStack(alignment: .center, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: meal.title)
                    if isEmpty {
                        Text("Add food")
                            .font(PickleFont.bodyMedium(17))
                            .foregroundStyle(Palette.tertiary)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(totals.kcal)")
                                .font(PickleFont.stat(28))
                                .foregroundStyle(Palette.primary)
                                .monospacedDigit()
                            Text("kcal")
                                .font(PickleFont.caption())
                                .foregroundStyle(Palette.tertiary)
                        }
                        Text("P \(totals.proteinG)  ·  C \(totals.carbsG)  ·  F \(totals.fatG)")
                            .font(PickleFont.caption(12))
                            .foregroundStyle(Palette.secondary)
                            .monospacedDigit()
                    }
                }
                Spacer()
                Image(systemName: isEmpty ? "plus" : "chevron.right")
                    .font(.system(size: isEmpty ? 16 : 13, weight: .medium))
                    .foregroundStyle(isEmpty ? Palette.primary : Palette.tertiary)
                    .frame(width: 32, height: 32)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEmpty ? "\(meal.title), no food logged, add"
                                    : "\(meal.title), \(totals.kcal) calories")
    }
}
