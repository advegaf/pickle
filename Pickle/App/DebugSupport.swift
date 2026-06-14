import Foundation

/// Launch-argument helpers for the screenshot/verification loop. DEBUG-only; release builds
/// see `none` and behave normally.
enum LaunchOptions {
    static var seedDemo: Bool { args.contains("--seed") }
    static var reset: Bool { args.contains("--reset") }

    /// `--onboard-step N` forces the onboarding flow to start at step N (for capturing each
    /// screen without tapping through).
    static var onboardStep: Int? {
        guard let i = args.firstIndex(of: "--onboard-step"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    /// `--open log` / `--open ai` / `--open quick` auto-presents a screen for screenshots.
    static var open: String? {
        guard let i = args.firstIndex(of: "--open"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// `--tab N` selects a tab on launch (0=Home … 4=More).
    static var tab: Int? {
        guard let i = args.firstIndex(of: "--tab"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    private static var args: [String] { ProcessInfo.processInfo.arguments }
}

#if DEBUG
import SwiftData

@MainActor
enum DemoSeed {
    /// Wipe everything (for a clean onboarding capture).
    static func reset(_ store: PickleStore) {
        let ctx = store.context
        for p in (try? ctx.fetch(FetchDescriptor<UserProfile>())) ?? [] { ctx.delete(p) }
        for f in (try? ctx.fetch(FetchDescriptor<FoodItemEntry>())) ?? [] { ctx.delete(f) }
        for l in (try? ctx.fetch(FetchDescriptor<LogEntry>())) ?? [] { ctx.delete(l) }
        for w in (try? ctx.fetch(FetchDescriptor<WeightEntry>())) ?? [] { ctx.delete(w) }
        for s in (try? ctx.fetch(FetchDescriptor<PlanSnapshot>())) ?? [] { ctx.delete(s) }
        try? ctx.save()
    }

    /// Onboarding complete but nothing logged — the first-run empty Home state.
    static func seedEmpty(_ store: PickleStore) {
        reset(store)
        var p = ProfileData()
        p.name = "Alex"; p.sex = .male; p.age = 28; p.heightCm = 180; p.weightKg = 82
        p.activity = .active; p.goal = .lose; p.weeklyRateKg = 0.5; p.split = .highProtein
        store.completeOnboarding(p)
    }

    /// A completed profile, a few days of history (for streak/activity/coach), and a couple
    /// of meals logged today.
    static func seed(_ store: PickleStore) {
        reset(store)
        var p = ProfileData()
        p.name = "Alex"; p.sex = .male; p.age = 28; p.heightCm = 180; p.weightKg = 82
        p.activity = .active; p.goal = .lose; p.weeklyRateKg = 0.5; p.split = .highProtein
        store.completeOnboarding(p)

        let today: [(String, String?, FoodNutrition, MealSlot)] = [
            ("Greek Yogurt", "Fage", FoodNutrition(kcalPer100: 97, proteinPer100: 10, carbsPer100: 4, fatPer100: 5, servingGrams: 170), .breakfast),
            ("Banana", nil, FoodNutrition(kcalPer100: 89, proteinPer100: 1.1, carbsPer100: 23, fatPer100: 0.3, servingGrams: 118), .breakfast),
            ("Grilled Chicken Bowl", "Chipotle", FoodNutrition(kcalPer100: 150, proteinPer100: 14, carbsPer100: 9, fatPer100: 6, servingGrams: 400), .lunch),
        ]

        // A realistic full day (~2000 kcal) used to backfill prior days, so the adaptive
        // maintenance estimate reads believably.
        let fullDay: [(String, String?, FoodNutrition, MealSlot)] = [
            ("Oatmeal", nil, FoodNutrition(kcalPer100: 71, proteinPer100: 2.5, carbsPer100: 12, fatPer100: 1.5, servingGrams: 350), .breakfast),
            ("Eggs", nil, FoodNutrition(kcalPer100: 143, proteinPer100: 13, carbsPer100: 0.7, fatPer100: 10, servingGrams: 100), .breakfast),
            ("Chicken & Rice", nil, FoodNutrition(kcalPer100: 140, proteinPer100: 12, carbsPer100: 18, fatPer100: 3, servingGrams: 450), .lunch),
            ("Salmon & Potato", nil, FoodNutrition(kcalPer100: 150, proteinPer100: 14, carbsPer100: 12, fatPer100: 6, servingGrams: 400), .dinner),
            ("Almonds", nil, FoodNutrition(kcalPer100: 579, proteinPer100: 21, carbsPer100: 22, fatPer100: 50, servingGrams: 28), .snack),
        ]

        // Backfill several prior days with full days so streak, activity, and Coach look real.
        for offset in 1...4 {
            guard let dayKey = DayKey.shifted(store.todayKey(), by: -offset),
                  let date = isoDate(dayKey) else { continue }
            for item in fullDay {
                let cand = candidate(item)
                store.log(cand.0, amount: 1, unit: .serving, meal: cand.1,
                          macros: cand.0.nutrition.macros(forGrams: cand.0.nutrition.servingGrams ?? 100),
                          at: date)
            }
        }

        // Today: a partial day (breakfast + lunch) so Home shows progress.
        for item in today {
            let cand = candidate(item)
            store.log(cand.0, amount: 1, unit: .serving, meal: cand.1,
                      macros: cand.0.nutrition.macros(forGrams: cand.0.nutrition.servingGrams ?? 100))
        }

        // A gentle downward weight series for adaptive math (~0.5 kg over two weeks).
        for offset in stride(from: 13, through: 0, by: -1) {
            if let dayKey = DayKey.shifted(store.todayKey(), by: -offset), let date = isoDate(dayKey) {
                store.addWeight(kg: 82.0 - Double(13 - offset) * 0.035, at: date)
            }
        }
    }

    private static func candidate(_ item: (String, String?, FoodNutrition, MealSlot)) -> (FoodCandidate, MealSlot) {
        (FoodCandidate(name: item.0, brand: item.1, source: .common,
                       sourceID: item.0.lowercased(), barcode: nil, nutrition: item.2), item.3)
    }

    private static func isoDate(_ key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: key)?.addingTimeInterval(12 * 3600)
    }
}
#endif
