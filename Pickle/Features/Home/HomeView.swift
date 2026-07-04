import SwiftUI

/// The Glow Home: greeting header, a week scrubber that drives the whole screen's
/// data, the calorie arc hero, macro cards, then meals and quick links.
///
/// Day semantics: `selectedDay` defaults to today and snaps back on day rollover or
/// app foreground. Viewing a past day is explicit backfill mode: the meals section is
/// titled with that date and empty-slot taps log to THAT day; the greeting, streak,
/// and the global tab-bar Log button always belong to today.
struct HomeView: View {
    @EnvironmentObject private var store: PickleStore
    @EnvironmentObject private var reminders: ReminderService
    var onLog: () -> Void = {}
    /// Log into a meal slot; `day` nil means today, otherwise an explicit backfill day.
    var onLogMeal: (MealSlot, String?) -> Void = { _, _ in }
    @State private var mealDetail: MealSlot?
    @State private var quickSheet: QuickSheet?
    @State private var showProfile = false
    @State private var showReminders = false
    /// The day the screen is showing. Empty until first appear, then always a valid key.
    @State private var selectedDay = ""
    /// Cached kcal-per-day for the strip, refreshed per store revision.
    @State private var dayKcal: [String: Int] = [:]
    /// Memoized prediction for the next unlogged slot (recomputed per revision/day).
    @State private var prediction: MealPrediction?
    /// A tapped prediction opens Food detail prefilled with the predicted food.
    @State private var predictedRoute: PredictedRoute?
    /// Detects midnight rollover across foreground/day-change events.
    @State private var lastKnownToday = ""
    /// Entries across the 28-day window + today (gates the one-time reminder prompt).
    @State private var historyEntryCount = 0
    @Environment(\.scenePhase) private var scenePhase

    private struct PredictedRoute: Identifiable {
        let candidate: FoodCandidate
        let slot: MealSlot
        var id: String { candidate.canonicalID }
    }

    private var profile: ProfileData { store.profile() }
    private var today: String { store.todayKey() }
    private var viewingToday: Bool { selectedDay.isEmpty || selectedDay == today }
    private var shownDay: String { viewingToday ? today : selectedDay }
    private var day: DiaryDay { store.diaryDay(shownDay) }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    greetingBlock

                    WeekStrip(today: today,
                              selected: shownDay,
                              dayKcal: dayKcal,
                              onSelect: { selectedDay = $0 })
                        .pickleEntrance(index: 1)

                    ArcGauge(consumed: day.totals.kcal,
                             target: profile.targets.kcal,
                             hasData: profile.targets.kcal > 0,
                             isEmptyDay: viewingToday && day.isEmpty)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s)
                        .pickleEntrance(index: 2)

                    MacroCardRow(consumed: day.totals, targets: profile.targets)
                        .pickleEntrance(index: 3)

                    // The predicted card belongs to TODAY only; hidden on past days.
                    // With a prediction it is one tap to log; with no slot history it
                    // shows only on an empty day, as the first-log nudge.
                    if viewingToday, let prediction,
                       prediction.food != nil || day.isEmpty {
                        PredictedMealCard(prediction: prediction) {
                            if let food = prediction.food,
                               let cand = store.foodCandidate(forCanonicalID: food.canonicalID) {
                                predictedRoute = PredictedRoute(candidate: cand, slot: prediction.slot)
                            } else {
                                onLogMeal(prediction.slot, nil)
                            }
                        }
                        .pickleEntrance(index: 4)
                    }

                    // One-time reminder opt-in after the third log ever: the retention
                    // lever needs an adoption moment, not just a bell.
                    if reminders.shouldOfferPrompt, historyEntryCount >= 3 {
                        reminderPrompt.pickleEntrance(index: 4)
                    }

                    mealsSection.pickleEntrance(index: 4)
                    quickLinks.pickleEntrance(index: 5)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $mealDetail) { meal in
            MealDetailView(meal: meal, localDay: shownDay)
                .environmentObject(store)
        }
        .sheet(item: $predictedRoute) { route in
            NavigationStack {
                FoodDetailView(candidate: route.candidate, presetMeal: route.slot) {
                    predictedRoute = nil
                }
            }
            .environmentObject(store)
            .presentationBackground(Palette.background)
        }
        .onAppear { syncDay() }
        .onChange(of: store.revision) { _, _ in refreshDayKcal() }
        .onChange(of: store.diaryDay(today).totals.kcal) { old, new in
            // Goal-hit moment: one celebration per crossing, today only.
            let target = profile.targets.kcal
            if target > 0, old < target, new >= target {
                Haptics.celebrate()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { syncDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { @MainActor in syncDay() }
        }
    }

    /// Snap the selection back to today after a rollover and refresh the strip cache.
    private func syncDay() {
        let now = store.todayKey()
        if selectedDay.isEmpty || lastKnownToday != now {
            selectedDay = now
            lastKnownToday = now
        }
        refreshDayKcal()
    }

    private func refreshDayKcal() {
        dayKcal = store.dailyKcal()
        let history = store.recentDays(back: 28)
        prediction = PredictedMealEngine.predict(history: history,
                                                 today: store.diaryDay(today))
        historyEntryCount = history.reduce(0) { $0 + $1.entries.count }
            + store.diaryDay(today).entries.count
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.m) {
            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(Palette.surface)
                        .overlay(Circle().strokeBorder(Palette.glassEdge, lineWidth: 1))
                        .frame(width: 40, height: 40)
                    Text(initials)
                        .font(PickleFont.bodyMedium(14))
                        .foregroundStyle(Palette.primary)
                }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Your profile")

            Spacer()

            BellChip(missed: reminders.missedCount(today: store.diaryDay(today), todayKey: today)) {
                showReminders = true
            }

            Button(action: onLog) {
                PickleIcon(.search, size: 17)
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 36, height: 36)
                    .background(Palette.surface)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Palette.glassEdge, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Search foods")
        }
        .sheet(isPresented: $showProfile) { ProfileView().environmentObject(store) }
        .sheet(isPresented: $showReminders) {
            RemindersSheet()
                .environmentObject(reminders)
        }
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(greeting)
                .font(PickleFont.heading(22))
                .foregroundStyle(Palette.primary)
                .accessibilityAddTraits(.isHeader)
            Text(todayLine)
                .font(PickleFont.caption())
                .foregroundStyle(Palette.secondary)
        }
    }

    // MARK: Meals

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: viewingToday ? "Today's meals" : dayTitle(shownDay))
            VStack(spacing: Spacing.m) {
                ForEach(MealSlot.allCases) { meal in
                    let entries = day.entries(for: meal)
                    MealCard(meal: meal, entries: entries) {
                        // Empty slot logs straight away (backfills when viewing a past
                        // day); a slot with food opens its detail.
                        if entries.isEmpty {
                            onLogMeal(meal, viewingToday ? nil : shownDay)
                        } else {
                            mealDetail = meal
                        }
                    }
                }
            }
        }
    }

    private var reminderPrompt: some View {
        HStack(spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Want a nudge at meal times?")
                    .font(PickleFont.bodyMedium(15))
                    .foregroundStyle(Palette.primary)
                Text("A quiet reminder keeps the streak alive.")
                    .font(PickleFont.caption(12))
                    .foregroundStyle(Palette.secondary)
            }
            Spacer()
            Button {
                reminders.markPromptShown()
                showReminders = true
            } label: {
                Text("Set up")
                    .font(PickleFont.button(14))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, Spacing.l)
                    .frame(height: 36)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.pressable)
            Button {
                reminders.markPromptShown()
            } label: {
                PickleIcon(.close, size: 12)
                    .foregroundStyle(Palette.tertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Dismiss reminder suggestion")
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 20)
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Quick links")
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

    // MARK: Copy

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        let name = profile.name.isEmpty ? "" : ", \(profile.name)"
        return "\(part)\(name)"
    }

    private var todayLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    /// "Tuesday, Jul 1" for a past day's meals section title.
    private func dayTitle(_ key: String) -> String {
        guard let date = DayKey.date(from: key) else { return key }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
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
                    SectionLabel(text: meal.title, color: Palette.tertiary)
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
                    .foregroundStyle(isEmpty ? Palette.secondary : Palette.tertiary)
                    .frame(width: 32, height: 32)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity)
            .glassCard(radius: 20)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEmpty ? "\(meal.title), no food logged, add"
                                    : "\(meal.title), \(totals.kcal) calories, view items")
    }
}

/// One meal's logged items for a day: a focused detail opened from the Home meal card. Shows
/// the meal's total + each item (with delete) and an "Add to <meal>" button that opens the Log
/// sheet preset to this meal (backfilling if the shown day is in the past).
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
                            .overlay(Capsule()
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
                .padding(.bottom, Spacing.l)
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
                LogSheet(presetMeal: meal,
                         logDay: localDay == store.todayKey() ? nil : localDay)
                    .environmentObject(store)
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
