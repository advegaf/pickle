import SwiftUI

/// The data-forward Home. The kcal-remaining ring leads; the editorial headline is large on
/// the first-run empty state and recedes to a quiet greeting once the day has data.
struct HomeView: View {
    @EnvironmentObject private var store: PickleStore
    var onLog: () -> Void = {}
    var onLogMeal: (MealSlot) -> Void = { _ in }
    @State private var mealDetail: MealSlot?
    @State private var quickSheet: QuickSheet?
    @State private var showProfile = false

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
                    .pickleEntrance(index: 1)

                    if streak >= 3 {
                        MilestoneBanner(title: "\(streak)-day streak",
                                        subtitle: "You're building real momentum. Keep it going.")
                            .pickleEntrance(index: 2)
                    }

                    if firstRun {
                        firstRunHint
                    }

                    mealsSection.pickleEntrance(index: 3)
                    quickLinks.pickleEntrance(index: 4)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.s)
                .padding(.bottom, 140)
            }

            FloatingPill(action: onLog)
                .padding(.trailing, Spacing.l)
                .padding(.bottom, 96)
        }
        .sheet(item: $mealDetail) { meal in
            MealDetailView(meal: meal, localDay: store.todayKey())
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.m) {
            Button { showProfile = true } label: {
                ZStack {
                    Circle().stroke(Palette.hairline, lineWidth: 1).frame(width: 40, height: 40)
                    Text(initials)
                        .font(PickleFont.eyebrow(13))
                        .foregroundStyle(Palette.primary)
                }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Your profile")
            Spacer()
            Button(action: onLog) {
                PickleIcon(.search, size: 18)
                    .foregroundStyle(Palette.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Search foods")
        }
        .sheet(isPresented: $showProfile) { ProfileView().environmentObject(store) }
    }

    private var firstRunHint: some View {
        HStack(spacing: Spacing.s) {
            PickleIcon(.arrowDownRight, size: 13)
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
                    let entries = day.entries(for: meal)
                    MealCard(meal: meal, entries: entries) {
                        // Empty slot logs straight away; a slot with food opens its detail.
                        if entries.isEmpty { onLogMeal(meal) } else { mealDetail = meal }
                    }
                }
            }
        }
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Quick links")
            GroupedListCard {
                ListRow(icon: .favorite, title: "Favorites") { quickSheet = .favorites }
                ListRowDivider()
                ListRow(icon: .bookmark, title: "Loved Meals") { quickSheet = .loved }
                ListRowDivider()
                ListRow(icon: .edit, title: "Custom Foods") { quickSheet = .custom }
            }
        }
        .sheet(item: $quickSheet) { which in
            NavigationStack {
                Group {
                    switch which {
                    case .favorites: SavedFoodsList(kind: .favorites)
                    case .custom: SavedFoodsList(kind: .custom)
                    case .loved: LovedMealsList()
                    }
                }
                .environmentObject(store)
                .background(Palette.background)
                .navigationTitle(which.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { quickSheet = nil }.foregroundStyle(Palette.primary)
                    }
                }
            }
            .presentationBackground(Palette.background)
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

/// Data-forward meal card: meal name + big kcal numeral + macro line. Tapping an empty slot
/// logs straight away; a slot with food opens its detail (its logged items).
struct MealCard: View {
    let meal: MealSlot
    let entries: [LoggedFood]
    let onTap: () -> Void

    private var totals: MacroTargets { entries.reduce(.zero) { $0 + $1.macros } }
    private var isEmpty: Bool { entries.isEmpty }

    var body: some View {
        Button(action: onTap) {
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
                            Text("cal")
                                .font(PickleFont.caption())
                                .foregroundStyle(Palette.tertiary)
                        }
                        MacroLine(macros: totals)
                    }
                }
                Spacer()
                PickleIcon(isEmpty ? .add : .chevronRight, size: isEmpty ? 16 : 13)
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
                                    : "\(meal.title), \(totals.kcal) calories, view items")
    }
}

/// One meal's logged items for a day: a focused detail opened from the Home meal card. Shows
/// the meal's total + each item (with delete) and an "Add to <meal>" button that opens the Log
/// sheet preset to this meal. Reuses the row + delete pattern from the Activity day detail.
struct MealDetailView: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss
    let meal: MealSlot
    let localDay: String
    @State private var route: Route?
    @State private var showSavePrompt = false
    @State private var mealName = ""
    @State private var justSaved = false

    private enum Route: Identifiable {
        case log
        case detail(FoodCandidate, LoggedFood)
        var id: String { switch self { case .log: return "log"; case .detail(_, let e): return "detail-\(e.id)" } }
    }

    private var entries: [LoggedFood] { store.diaryDay(localDay).entries(for: meal) }
    private var totals: MacroTargets { entries.reduce(.zero) { $0 + $1.macros } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    if entries.isEmpty {
                        Text("Nothing logged for \(meal.title.lowercased()) yet.")
                            .font(PickleFont.body(15))
                            .foregroundStyle(Palette.tertiary)
                            .padding(.top, Spacing.xl)
                    } else {
                        header
                        VStack(spacing: 0) {
                            ForEach(entries) { entry in
                                entryRow(entry)
                                if entry.id != entries.last?.id {
                                    Divider().overlay(Palette.hairline)
                                }
                            }
                        }
                        Button { mealName = meal.title; showSavePrompt = true } label: {
                            HStack(spacing: Spacing.s) {
                                PickleIcon(justSaved ? .health : .favorite, size: 15)
                                Text(justSaved ? "Meal saved" : "Save as a meal")
                            }
                            .font(PickleFont.button(14))
                            .foregroundStyle(justSaved ? Palette.success : Palette.primary)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .overlay(RoundedRectangle(cornerRadius: Radius.button)
                                .stroke((justSaved ? Palette.success : Palette.primary).opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.pressable)
                        .disabled(justSaved)
                        .padding(.top, Spacing.s)
                        .animation(Motion.easeOut, value: justSaved)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.l)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Palette.background)
            .navigationTitle(meal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.primary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Add to \(meal.title)") { route = .log }
                    .padding(.horizontal, Spacing.screen)
                    .padding(.vertical, Spacing.m)
                    .background(Palette.background)
            }
        }
        .presentationBackground(Palette.background)
        .sheet(item: $route) { r in
            switch r {
            case .log:
                LogSheet(presetMeal: meal).environmentObject(store)
            case .detail(let cand, let entry):
                NavigationStack {
                    FoodDetailView(candidate: cand, presetMeal: meal, editing: entry) { route = nil }
                }
                .environmentObject(store)
                .presentationBackground(Palette.background)
            }
        }
        .alert("Save as a meal", isPresented: $showSavePrompt) {
            TextField("Meal name", text: $mealName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let n = mealName.trimmingCharacters(in: .whitespaces)
                store.saveLovedMeal(name: n.isEmpty ? meal.title : n, from: entries)
                Haptics.confirm()
                justSaved = true
            }
        } message: {
            Text("Saves these \(entries.count) item\(entries.count == 1 ? "" : "s") to your Loved meals to re-log anytime.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(totals.kcal)")
                .font(PickleFont.stat(40)).foregroundStyle(Palette.primary).monospacedDigit()
            Text("cal").font(PickleFont.body()).foregroundStyle(Palette.tertiary)
            Spacer()
            MacroLine(macros: totals)
        }
    }

    private func entryRow(_ entry: LoggedFood) -> some View {
        HStack {
            Button {
                if let cand = store.foodCandidate(forCanonicalID: entry.canonicalID) {
                    route = .detail(cand, entry); Haptics.select()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name).font(PickleFont.bodyMedium(15)).foregroundStyle(Palette.primary)
                        Text(portionLabel(entry)).font(PickleFont.caption(12)).foregroundStyle(Palette.tertiary)
                    }
                    Spacer()
                    Text("\(entry.macros.kcal) cal")
                        .font(PickleFont.caption()).foregroundStyle(Palette.secondary).monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("\(entry.name), \(entry.macros.kcal) calories, view")

            Button { store.deleteLog(id: entry.id); Haptics.select() } label: {
                PickleIcon(.close, size: 11)
                    .foregroundStyle(Palette.tertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Remove \(entry.name)")
        }
        .frame(minHeight: 48)
    }

    private func portionLabel(_ e: LoggedFood) -> String {
        let amt = e.amount == e.amount.rounded() ? String(Int(e.amount)) : String(format: "%.1f", e.amount)
        return "\(amt) \(e.unit.abbreviation)"
    }
}

/// Which saved-foods list a Home quick link opens.
enum QuickSheet: String, Identifiable {
    case favorites, custom, loved
    var id: String { rawValue }
    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .custom: return "Custom Foods"
        case .loved: return "Loved Meals"
        }
    }
}
