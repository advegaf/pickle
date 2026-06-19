import Foundation

// MARK: - Profile inputs

enum Sex: String, Codable, CaseIterable, Sendable {
    case male, female
}

/// Activity multiplier applied to BMR for TDEE (standard Mifflin-St Jeor multipliers).
enum ActivityLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case sedentary, light, moderate, active, veryActive
    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Active"
        case .veryActive: return "Very active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Exercise 1–3 days/week"
        case .moderate: return "Exercise 3–5 days/week"
        case .active: return "Exercise 6–7 days/week"
        case .veryActive: return "Hard daily exercise or physical job"
        }
    }
}

enum GoalDirection: String, Codable, CaseIterable, Sendable, Identifiable {
    case lose, maintain, gain
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lose: return "Lose weight"
        case .maintain: return "Maintain"
        case .gain: return "Gain weight"
        }
    }
}

/// Macro distribution as fractions of total energy. Always sums to 1.0 (validated).
struct MacroSplit: Codable, Equatable, Sendable {
    var protein: Double
    var carbs: Double
    var fat: Double

    static let balanced = MacroSplit(protein: 0.30, carbs: 0.40, fat: 0.30)
    static let highProtein = MacroSplit(protein: 0.40, carbs: 0.35, fat: 0.25)
    static let lowCarb = MacroSplit(protein: 0.35, carbs: 0.25, fat: 0.40)

    enum Preset: String, CaseIterable, Identifiable, Sendable {
        case balanced, highProtein, lowCarb, custom
        var id: String { rawValue }
        var title: String {
            switch self {
            case .balanced: return "Balanced"
            case .highProtein: return "High protein"
            case .lowCarb: return "Low carb"
            case .custom: return "Custom"
            }
        }
        var split: MacroSplit? {
            switch self {
            case .balanced: return .balanced
            case .highProtein: return .highProtein
            case .lowCarb: return .lowCarb
            case .custom: return nil
            }
        }
    }

    var isValid: Bool { abs((protein + carbs + fat) - 1.0) < 0.001 }
}

enum MealSlot: String, Codable, CaseIterable, Sendable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }
    var sortOrder: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The meal that best matches the current time of day, used as the default when logging
    /// from the generic Log pill. The user can still tap to change it.
    static var current: MealSlot { current(at: Date()) }

    /// Time-of-day to meal mapping. Breakfast 04:00-10:59, lunch 11:00-15:59,
    /// dinner 16:00-21:59, otherwise snack (late night / pre-dawn).
    static func current(at date: Date, calendar: Calendar = .current) -> MealSlot {
        switch calendar.component(.hour, from: date) {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default: return .snack
        }
    }
}

// MARK: - Macros

/// kcal calories per gram of each macro (Atwater factors).
enum Atwater {
    static let protein = 4.0
    static let carbs = 4.0
    static let fat = 9.0
}

/// A nutrition target or a logged total. Calories + macro grams.
struct MacroTargets: Codable, Equatable, Sendable {
    var kcal: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int

    static let zero = MacroTargets(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)

    static func + (a: MacroTargets, b: MacroTargets) -> MacroTargets {
        MacroTargets(kcal: a.kcal + b.kcal,
                     proteinG: a.proteinG + b.proteinG,
                     carbsG: a.carbsG + b.carbsG,
                     fatG: a.fatG + b.fatG)
    }

    /// kcal implied by the macro grams (sanity reference).
    var impliedKcal: Double {
        Double(proteinG) * Atwater.protein + Double(carbsG) * Atwater.carbs + Double(fatG) * Atwater.fat
    }
}

// MARK: - Serving units

/// Units we recognize, grouped by physical dimension. Conversion is only valid within
/// a dimension (mass↔mass, volume↔volume); cross-dimension needs a food-specific bridge.
enum ServingUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case gram, ounce, pound          // mass
    case milliliter, fluidOunce, cup, tablespoon, teaspoon  // volume
    case serving, piece              // count
    var id: String { rawValue }

    enum Dimension { case mass, volume, count }

    var dimension: Dimension {
        switch self {
        case .gram, .ounce, .pound: return .mass
        case .milliliter, .fluidOunce, .cup, .tablespoon, .teaspoon: return .volume
        case .serving, .piece: return .count
        }
    }

    /// Factor to the dimension's base unit (grams for mass, milliliters for volume,
    /// 1 for count). nil means "no fixed factor" (count units are food-specific).
    var toBase: Double? {
        switch self {
        case .gram: return 1
        case .ounce: return 28.3495
        case .pound: return 453.592
        case .milliliter: return 1
        case .fluidOunce: return 29.5735
        case .cup: return 240
        case .tablespoon: return 15
        case .teaspoon: return 5
        case .serving, .piece: return nil
        }
    }

    var abbreviation: String {
        switch self {
        case .gram: return "g"
        case .ounce: return "oz"
        case .pound: return "lb"
        case .milliliter: return "ml"
        case .fluidOunce: return "fl oz"
        case .cup: return "cup"
        case .tablespoon: return "tbsp"
        case .teaspoon: return "tsp"
        case .serving: return "serving"
        case .piece: return "piece"
        }
    }
}
