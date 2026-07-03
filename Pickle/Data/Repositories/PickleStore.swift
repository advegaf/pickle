import Foundation
import SwiftData

/// Profile as a value type for the UI.
struct ProfileData: Equatable, Sendable {
    var name: String = ""
    var sex: Sex = .male
    var age: Int = 30
    var heightCm: Double = 175
    var weightKg: Double = 75
    /// Lean body mass in kg from Apple Health, 0 when unknown.
    var leanMassKg: Double = 0
    var activity: ActivityLevel = .moderate
    var goal: GoalDirection = .maintain
    var weeklyRateKg: Double = 0
    var split: MacroSplit = .balanced
    var targets: MacroTargets = .zero
    var onboardingComplete: Bool = false

    var planProfile: PlanCalculator.Profile {
        .init(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg, activity: activity,
              leanMassKg: leanMassKg > 0 ? leanMassKg : nil)
    }
    var planGoal: PlanCalculator.Goal {
        .init(direction: goal, weeklyRateKg: weeklyRateKg, split: split)
    }
}

/// The app's single SwiftData-backed store. `@MainActor` so the `ModelContext` is never
/// touched off the main actor; every value it returns is a Sendable DTO. Mutations recompute
/// and persist the widget snapshot in the same turn.
@MainActor
final class PickleStore: ObservableObject {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    /// Bumped on every diary mutation so SwiftUI views re-read.
    @Published private(set) var revision = 0

    init(container: ModelContainer) {
        self.container = container
    }

    static func live() -> PickleStore { PickleStore(container: Database.makeContainer()) }
    static func inMemory() -> PickleStore { PickleStore(container: Database.makeContainer(inMemory: true)) }

    private func bump() { revision &+= 1 }
    /// Visible to other files (e.g. the remote-change observer) to nudge the UI to re-read.
    func bumpExternal() { revision &+= 1 }
    func todayKey(_ tz: TimeZone = .current) -> String { DayKey.localDay(for: Date(), in: tz) }

    // MARK: - Profile

    func profileModel() -> UserProfile {
        if let existing = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            return existing
        }
        let p = UserProfile()
        context.insert(p)
        return p
    }

    func profile() -> ProfileData {
        let m = profileModel()
        return ProfileData(name: m.name, sex: m.sex, age: m.age, heightCm: m.heightCm,
                           weightKg: m.weightKg, leanMassKg: m.leanMassKg, activity: m.activity, goal: m.goal,
                           weeklyRateKg: m.weeklyRateKg, split: m.split, targets: m.targets,
                           onboardingComplete: m.onboardingComplete)
    }

    var hasCompletedOnboarding: Bool {
        (try? context.fetch(FetchDescriptor<UserProfile>()).first?.onboardingComplete) ?? false
    }

    /// Persist profile inputs, recompute the plan, mark onboarding complete, snapshot the plan.
    func completeOnboarding(_ data: ProfileData) {
        let m = profileModel()
        apply(data, to: m)
        let targets = PlanCalculator.plan(data.planProfile, data.planGoal)
        setTargets(targets, on: m)
        m.onboardingComplete = true
        m.planUpdatedAt = Date()
        recordPlanSnapshot(targets, reason: "Initial plan from your profile.")
        // Seed an initial weight from the profile so the adaptive engine has a starting point.
        addWeight(kg: data.weightKg)
        try? context.save()
        refreshWidgetSnapshot()
        bump()
    }

    func updateProfile(_ data: ProfileData) {
        let m = profileModel()
        apply(data, to: m)
        try? context.save()
        bump()
    }

    /// Recompute the plan from current profile inputs (manual "recalculate").
    func recalculatePlan() {
        let m = profileModel()
        let data = profile()
        let targets = PlanCalculator.plan(data.planProfile, data.planGoal)
        setTargets(targets, on: m)
        m.planUpdatedAt = Date()
        recordPlanSnapshot(targets, reason: "Recalculated from your profile.")
        try? context.save()
        refreshWidgetSnapshot()
        bump()
    }

    func applyAdaptive(_ result: AdaptivePlanEngine.Result) {
        guard result.changed else { return }
        let m = profileModel()
        setTargets(result.macros, on: m)
        m.planUpdatedAt = Date()
        recordPlanSnapshot(result.macros, reason: result.reason,
                           maintenance: result.estimatedMaintenanceKcal)
        try? context.save()
        refreshWidgetSnapshot()
        bump()
    }

    private func apply(_ data: ProfileData, to m: UserProfile) {
        m.name = data.name; m.sex = data.sex; m.age = data.age
        m.heightCm = data.heightCm; m.weightKg = data.weightKg; m.leanMassKg = data.leanMassKg
        m.activity = data.activity; m.goal = data.goal; m.weeklyRateKg = data.weeklyRateKg
        m.split = data.split
    }

    private func setTargets(_ t: MacroTargets, on m: UserProfile) {
        m.targetKcal = t.kcal; m.targetProteinG = t.proteinG
        m.targetCarbsG = t.carbsG; m.targetFatG = t.fatG
    }

    // MARK: - Diary

    func diaryDay(_ localDay: String) -> DiaryDay {
        let descriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate { $0.localDay == localDay },
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return DiaryDay(localDay: localDay, entries: entries.map(LoggedFood.init))
    }

    func today() -> DiaryDay { diaryDay(todayKey()) }

    @discardableResult
    func log(_ candidate: FoodCandidate, amount: Double, unit: ServingUnit,
             meal: MealSlot, macros: MacroTargets, at date: Date = Date()) -> Bool {
        let food = upsertFood(from: candidate, markUsed: true)
        let entry = LogEntry()
        entry.loggedAt = date
        entry.localDay = DayKey.localDay(for: date)
        entry.meal = meal
        entry.name = candidate.name
        entry.brand = candidate.brand
        entry.canonicalID = candidate.canonicalID
        entry.amount = amount
        entry.unit = unit
        entry.kcal = macros.kcal
        entry.proteinG = macros.proteinG
        entry.carbsG = macros.carbsG
        entry.fatG = macros.fatG
        entry.food = food
        context.insert(entry)
        try? context.save()
        refreshWidgetSnapshot()
        HealthKitService.shared.write(macros: macros, date: date)
        bump()
        return true
    }

    /// The trailing `back` days of diary BEFORE today, oldest first, in one ranged fetch
    /// (feeds the prediction engine and any history-window feature without per-day queries).
    func recentDays(back: Int) -> [DiaryDay] {
        let today = todayKey()
        guard back > 0, let startKey = DayKey.shifted(today, by: -back) else { return [] }
        let descriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate { $0.localDay >= startKey && $0.localDay < today },
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        let grouped = Dictionary(grouping: entries.map(LoggedFood.init), by: \.localDay)
        return grouped.keys.sorted().map { DiaryDay(localDay: $0, entries: grouped[$0] ?? []) }
    }

    /// All diary days, newest first, used by export.
    func allDiaryDays() -> [DiaryDay] {
        let entries = (try? context.fetch(FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\.loggedAt)]))) ?? []
        let grouped = Dictionary(grouping: entries.map(LoggedFood.init), by: \.localDay)
        return grouped.keys.sorted(by: >).map { DiaryDay(localDay: $0, entries: grouped[$0] ?? []) }
    }

    func deleteLog(id: UUID) {
        let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.id == id })
        if let entry = try? context.fetch(descriptor).first {
            context.delete(entry)
            try? context.save()
            refreshWidgetSnapshot()
            bump()
        }
    }

    /// Permanently wipe every record on this device (profile, diary, weights, plans, saved foods,
    /// loved meals). After this the app has no profile, so it returns to onboarding. Irreversible.
    func deleteAllData() {
        for p in (try? context.fetch(FetchDescriptor<UserProfile>())) ?? [] { context.delete(p) }
        for f in (try? context.fetch(FetchDescriptor<FoodItemEntry>())) ?? [] { context.delete(f) }
        for l in (try? context.fetch(FetchDescriptor<LogEntry>())) ?? [] { context.delete(l) }
        for w in (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? [] { context.delete(w) }
        for s in (try? context.fetch(FetchDescriptor<PlanSnapshot>())) ?? [] { context.delete(s) }
        for m in (try? context.fetch(FetchDescriptor<LovedMeal>())) ?? [] { context.delete(m) }
        for i in (try? context.fetch(FetchDescriptor<LovedMealItem>())) ?? [] { context.delete(i) }
        try? context.save()
        refreshWidgetSnapshot()
        bump()
    }

    /// Update an existing logged entry in place (portion / unit / meal / macros), so editing a
    /// logged item changes it instead of adding a duplicate.
    func updateLog(id: UUID, amount: Double, unit: ServingUnit, meal: MealSlot, macros: MacroTargets) {
        let descriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.id == id })
        guard let entry = try? context.fetch(descriptor).first else { return }
        entry.amount = amount
        entry.unit = unit
        entry.meal = meal
        entry.kcal = macros.kcal
        entry.proteinG = macros.proteinG
        entry.carbsG = macros.carbsG
        entry.fatG = macros.fatG
        try? context.save()
        refreshWidgetSnapshot()
        bump()
    }

    func loggedDays() -> Set<String> {
        let entries = (try? context.fetch(FetchDescriptor<LogEntry>())) ?? []
        return Set(entries.map(\.localDay).filter { !$0.isEmpty })
    }

    // MARK: - Foods (recents / favorites / custom / cache)

    @discardableResult
    func upsertFood(from candidate: FoodCandidate, markUsed: Bool = false) -> FoodItemEntry {
        let cid = candidate.canonicalID
        let descriptor = FetchDescriptor<FoodItemEntry>(predicate: #Predicate { $0.canonicalID == cid })
        let food = (try? context.fetch(descriptor).first) ?? {
            let f = FoodItemEntry()
            f.canonicalID = cid
            context.insert(f)
            return f
        }()
        food.name = candidate.name
        food.brand = candidate.brand
        food.source = candidate.source
        food.sourceID = candidate.sourceID
        food.barcode = candidate.barcode
        food.kcalPer100 = candidate.nutrition.kcalPer100
        food.proteinPer100 = candidate.nutrition.proteinPer100
        food.carbsPer100 = candidate.nutrition.carbsPer100
        food.fatPer100 = candidate.nutrition.fatPer100
        food.servingGrams = candidate.nutrition.servingGrams
        if markUsed { food.lastUsedAt = Date() }
        return food
    }

    func saveCustomFood(name: String, brand: String?, nutrition: FoodNutrition) -> SavedFood {
        let f = FoodItemEntry()
        f.canonicalID = "custom:\(UUID().uuidString)"
        f.name = name
        f.brand = brand
        f.source = .custom
        f.sourceID = f.canonicalID
        f.isCustom = true
        f.kcalPer100 = nutrition.kcalPer100
        f.proteinPer100 = nutrition.proteinPer100
        f.carbsPer100 = nutrition.carbsPer100
        f.fatPer100 = nutrition.fatPer100
        f.servingGrams = nutrition.servingGrams
        context.insert(f)
        try? context.save()
        bump()
        return SavedFood(f)
    }

    func recents(limit: Int = 20) -> [SavedFood] {
        var descriptor = FetchDescriptor<FoodItemEntry>(
            predicate: #Predicate { $0.lastUsedAt != nil },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map(SavedFood.init)
    }

    func favorites() -> [SavedFood] {
        let descriptor = FetchDescriptor<FoodItemEntry>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(SavedFood.init)
    }

    func customFoods() -> [SavedFood] {
        let descriptor = FetchDescriptor<FoodItemEntry>(
            predicate: #Predicate { $0.isCustom == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(SavedFood.init)
    }

    /// Reconstruct a food definition from a canonicalID (e.g. to open a logged item's detail).
    func foodCandidate(forCanonicalID cid: String) -> FoodCandidate? {
        let descriptor = FetchDescriptor<FoodItemEntry>(predicate: #Predicate { $0.canonicalID == cid })
        return (try? context.fetch(descriptor).first)?.candidate()
    }

    // MARK: - Loved meals (saved combinations)

    /// Save a combination of logged items (e.g. a whole meal section) as a reusable loved meal.
    func saveLovedMeal(name: String, from entries: [LoggedFood]) {
        let meal = LovedMeal()
        meal.name = name.trimmingCharacters(in: .whitespaces)
        meal.items = entries.map { e in
            let it = LovedMealItem()
            it.foodCanonicalID = e.canonicalID
            it.name = e.name
            it.amount = e.amount
            it.unit = e.unit
            it.kcal = e.macros.kcal
            it.proteinG = e.macros.proteinG
            it.carbsG = e.macros.carbsG
            it.fatG = e.macros.fatG
            return it
        }
        context.insert(meal)
        try? context.save()
        bump()
    }

    func lovedMeals() -> [LovedMealDTO] {
        let descriptor = FetchDescriptor<LovedMeal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map(LovedMealDTO.init)
    }

    func deleteLovedMeal(id: UUID) {
        let descriptor = FetchDescriptor<LovedMeal>(predicate: #Predicate { $0.id == id })
        if let m = try? context.fetch(descriptor).first {
            context.delete(m)
            try? context.save()
            bump()
        }
    }

    /// Re-log every item of a loved meal into the given slot.
    func logLovedMeal(id: UUID, into slot: MealSlot) {
        let descriptor = FetchDescriptor<LovedMeal>(predicate: #Predicate { $0.id == id })
        guard let m = try? context.fetch(descriptor).first else { return }
        for it in (m.items ?? []) {
            let candidate = foodCandidate(forCanonicalID: it.foodCanonicalID)
                ?? FoodCandidate(name: it.name, brand: nil, source: .custom, sourceID: it.foodCanonicalID,
                                 barcode: nil,
                                 nutrition: FoodNutrition(kcalPer100: 0, proteinPer100: 0,
                                                          carbsPer100: 0, fatPer100: 0, servingGrams: nil))
            _ = log(candidate, amount: it.amount, unit: it.unit, meal: slot, macros: it.macros)
        }
        bump()
    }

    func toggleFavorite(canonicalID: String) {
        let descriptor = FetchDescriptor<FoodItemEntry>(predicate: #Predicate { $0.canonicalID == canonicalID })
        if let food = try? context.fetch(descriptor).first {
            food.isFavorite.toggle()
            try? context.save()
            bump()
        }
    }

    func deleteFood(canonicalID: String) {
        let descriptor = FetchDescriptor<FoodItemEntry>(predicate: #Predicate { $0.canonicalID == canonicalID })
        if let food = try? context.fetch(descriptor).first {
            context.delete(food)
            try? context.save()
            bump()
        }
    }

    // MARK: - Weight

    func addWeight(kg: Double, at date: Date = Date(), fromHealthKit: Bool = false) {
        let w = WeightEntry()
        w.weightKg = kg
        w.recordedAt = date
        w.localDay = DayKey.localDay(for: date)
        w.fromHealthKit = fromHealthKit
        context.insert(w)
        try? context.save()
        bump()
    }

    func weights() -> [WeightSample] {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.recordedAt)])
        return ((try? context.fetch(descriptor)) ?? []).map {
            WeightSample(date: $0.recordedAt, localDay: $0.localDay, kg: $0.weightKg)
        }
    }

    // MARK: - Plan history

    private func recordPlanSnapshot(_ t: MacroTargets, reason: String, maintenance: Int? = nil) {
        let s = PlanSnapshot()
        s.kcal = t.kcal; s.proteinG = t.proteinG; s.carbsG = t.carbsG; s.fatG = t.fatG
        s.reason = reason
        s.estimatedMaintenanceKcal = maintenance
        context.insert(s)
    }

    func planHistory() -> [PlanRecord] {
        let descriptor = FetchDescriptor<PlanSnapshot>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map {
            PlanRecord(date: $0.createdAt, kcal: $0.kcal, reason: $0.reason,
                       maintenance: $0.estimatedMaintenanceKcal)
        }
    }

    // MARK: - Widget snapshot

    /// Today's diary distilled into the small value type the widget reads. Exposed so the DEBUG
    /// widget gallery can render real numbers without depending on the App-Group file (which the
    /// simulator may not provision).
    func currentSnapshot() -> DiarySnapshot {
        let day = today()
        let t = profileModel().targets
        let totals = day.totals
        return DiarySnapshot(
            localDay: day.localDay, updatedAt: Date(),
            consumedKcal: totals.kcal, targetKcal: t.kcal,
            proteinG: totals.proteinG, proteinTarget: t.proteinG,
            carbsG: totals.carbsG, carbsTarget: t.carbsG,
            fatG: totals.fatG, fatTarget: t.fatG,
            mealsLogged: day.loggedMealCount, mealsTotal: MealSlot.allCases.count)
    }

    func refreshWidgetSnapshot() {
        DiarySnapshotStore.write(currentSnapshot())
        WidgetReloader.reload()
    }
}

struct WeightSample: Equatable, Sendable {
    let date: Date
    let localDay: String
    let kg: Double
}

struct PlanRecord: Identifiable, Equatable, Sendable {
    let date: Date
    let kcal: Int
    let reason: String
    let maintenance: Int?
    var id: Date { date }
}
