import SwiftUI
import WidgetKit

// Compiled into BOTH the widget extension and the app. The widget renders these inside its
// timeline entry views; the app renders them in a DEBUG-only gallery (`--open widgets`) so the
// layouts can be screenshot-verified without adding the widgets to the springboard by hand.

// Local palette (the app's Tokens live in the app target; the widget keeps its own minimal set).
enum W {
    static let bg = Color.black
    static let primary = Color.white
    static let secondary = Color(.sRGB, white: 0.64, opacity: 1)   // ~#A3A3A3
    static let tertiary = Color(.sRGB, white: 0.54, opacity: 1)    // ~#8A8A8A
    static let faint = Color(.sRGB, white: 0.36, opacity: 1)
    static let over = Color(.sRGB, red: 0.898, green: 0.282, blue: 0.302, opacity: 1)   // #E5484D
    static let protein = Color(.sRGB, red: 0.91, green: 0.89, blue: 0.83, opacity: 1)
    static let carbs = Color(.sRGB, red: 0.79, green: 0.76, blue: 0.69, opacity: 1)
    static let fat = Color(.sRGB, red: 0.69, green: 0.66, blue: 0.56, opacity: 1)
}

// MARK: - Building blocks

/// A trimmed progress ring. `tint` lets the Macros widget reuse it for a protein ring; the
/// calorie widget passes white (or the over-red) so the over-state reads on the home screen.
struct RingMini: View {
    let fraction: Double
    let lineWidth: CGFloat
    var tint: Color = W.primary

    var body: some View {
        ZStack {
            Circle().stroke(W.faint.opacity(0.4), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Kcal-remaining ring. Thin wrapper over `RingMini` that picks white vs the over-red.
struct KcalRingMini: View {
    let fraction: Double
    let lineWidth: CGFloat
    var over: Bool = false
    var body: some View { RingMini(fraction: fraction, lineWidth: lineWidth, tint: over ? W.over : W.primary) }
}

/// Discrete meals-logged dots (filled = logged, hollow = remaining). No "·" separators.
struct MealDotsMini: View {
    let logged: Int
    let total: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                Circle()
                    .fill(i < logged ? W.primary : Color.clear)
                    .overlay(Circle().stroke(W.faint.opacity(0.6), lineWidth: 1))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

struct MacroBarMini: View {
    let short: String
    let value: Int
    let target: Int
    let tint: Color

    private var fraction: Double { target > 0 ? min(Double(value) / Double(target), 1) : 0 }

    var body: some View {
        HStack(spacing: 5) {
            Text(short).font(.system(size: 9, weight: .medium)).foregroundStyle(W.tertiary).frame(width: 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(W.faint.opacity(0.35))
                    Capsule().fill(tint).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: - Calories: home families (full color)

struct CalorieHome: View {
    let snap: DiarySnapshot
    let small: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                KcalRingMini(fraction: snap.fraction, lineWidth: 8, over: snap.isOver)
                VStack(spacing: 0) {
                    Text("\(snap.isOver ? snap.overKcal : snap.remainingKcal)")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(snap.isOver ? W.over : W.primary).monospacedDigit()
                    Text(snap.isOver ? "OVER" : "LEFT").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(snap.isOver ? W.over : W.tertiary)
                }
            }
            .frame(width: 92, height: 92)

            if !small {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DAILY FUEL").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(W.tertiary)
                    MacroBarMini(short: "P", value: snap.proteinG, target: snap.proteinTarget, tint: W.protein)
                    MacroBarMini(short: "C", value: snap.carbsG, target: snap.carbsTarget, tint: W.carbs)
                    MacroBarMini(short: "F", value: snap.fatG, target: snap.fatTarget, tint: W.fat)
                    Text("\(snap.consumedKcal) / \(snap.targetKcal) cal")
                        .font(.system(size: 11)).foregroundStyle(W.secondary).monospacedDigit()
                }
            }
        }
        .padding(small ? 4 : 8)
    }
}

struct CalorieLarge: View {
    let snap: DiarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DAILY FUEL").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(W.tertiary)
            HStack(spacing: 18) {
                ZStack {
                    KcalRingMini(fraction: snap.fraction, lineWidth: 10, over: snap.isOver)
                    VStack(spacing: 0) {
                        Text("\(snap.isOver ? snap.overKcal : snap.remainingKcal)")
                            .font(.system(size: 30, weight: .bold)).foregroundStyle(snap.isOver ? W.over : W.primary).monospacedDigit()
                        Text(snap.isOver ? "OVER" : "LEFT").font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(snap.isOver ? W.over : W.tertiary)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 11) {
                    MacroBarMini(short: "P", value: snap.proteinG, target: snap.proteinTarget, tint: W.protein)
                    MacroBarMini(short: "C", value: snap.carbsG, target: snap.carbsTarget, tint: W.carbs)
                    MacroBarMini(short: "F", value: snap.fatG, target: snap.fatTarget, tint: W.fat)
                }
            }
            Spacer(minLength: 0)
            HStack {
                MealDotsMini(logged: snap.mealsLogged, total: snap.mealsTotal)
                Spacer()
                Text("\(snap.consumedKcal) / \(snap.targetKcal) cal")
                    .font(.system(size: 12)).foregroundStyle(W.secondary).monospacedDigit()
            }
        }
        .padding(16)
    }
}

// MARK: - Calories: lock families (monochrome; the word OVER carries the over-state, not color)

struct CalorieCircular: View {
    let snap: DiarySnapshot
    var body: some View {
        ZStack {
            RingMini(fraction: snap.fraction, lineWidth: 5)
            VStack(spacing: 0) {
                Text("\(snap.isOver ? snap.overKcal : snap.remainingKcal)")
                    .font(.system(size: 17, weight: .bold)).monospacedDigit()
                Text(snap.isOver ? "over" : "left").font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .widgetAccentable()
        }
    }
}

struct CalorieRectangular: View {
    let snap: DiarySnapshot
    var body: some View {
        HStack(spacing: 10) {
            RingMini(fraction: snap.fraction, lineWidth: 4).frame(width: 34, height: 34).widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(snap.isOver ? snap.overKcal : snap.remainingKcal)")
                        .font(.system(size: 20, weight: .bold)).monospacedDigit().widgetAccentable()
                    Text(snap.isOver ? "cal over" : "cal left").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                ViewThatFits {
                    Text("P \(snap.proteinG)   C \(snap.carbsG)   F \(snap.fatG)")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                    Text("P\(snap.proteinG) C\(snap.carbsG) F\(snap.fatG)")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct CalorieInline: View {
    let snap: DiarySnapshot
    var body: some View {
        Label(snap.isOver ? "\(snap.overKcal) cal over" : "\(snap.remainingKcal) cal left",
              systemImage: "flame.fill")
    }
}

// MARK: - Macros widget views

struct MacrosHome: View {
    let snap: DiarySnapshot
    let small: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 10 : 12) {
            Text("MACROS").font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(W.tertiary)
            row("P", snap.proteinG, snap.proteinTarget, W.protein)
            row("C", snap.carbsG, snap.carbsTarget, W.carbs)
            row("F", snap.fatG, snap.fatTarget, W.fat)
            if !small {
                Spacer(minLength: 0)
                Text("\(snap.consumedKcal) / \(snap.targetKcal) cal")
                    .font(.system(size: 11)).foregroundStyle(W.secondary).monospacedDigit()
            }
        }
        .padding(small ? 12 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ short: String, _ value: Int, _ target: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(macroName(short)).font(.system(size: 11, weight: .medium)).foregroundStyle(W.secondary)
                Spacer()
                Text("\(value) / \(target) g").font(.system(size: 11)).foregroundStyle(W.tertiary).monospacedDigit()
            }
            MacroBarMini(short: short, value: value, target: target, tint: tint)
        }
    }

    private func macroName(_ short: String) -> String {
        switch short { case "P": return "Protein"; case "C": return "Carbs"; default: return "Fat" }
    }
}

/// Protein is the headline macro, so the circular lock widget rings protein toward its target.
struct MacrosCircular: View {
    let snap: DiarySnapshot
    private var fraction: Double {
        snap.proteinTarget > 0 ? min(Double(snap.proteinG) / Double(snap.proteinTarget), 1) : 0
    }
    var body: some View {
        ZStack {
            RingMini(fraction: fraction, lineWidth: 5)
            VStack(spacing: 0) {
                Text("\(snap.proteinG)").font(.system(size: 16, weight: .bold)).monospacedDigit()
                Text("P g").font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
            }
            .widgetAccentable()
        }
    }
}

struct MacrosRectangular: View {
    let snap: DiarySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            line("Protein", snap.proteinG, snap.proteinTarget)
            line("Carbs", snap.carbsG, snap.carbsTarget)
            line("Fat", snap.fatG, snap.fatTarget)
        }
        .widgetAccentable()
    }

    private func line(_ name: String, _ value: Int, _ target: Int) -> some View {
        HStack(spacing: 6) {
            Text(name).font(.system(size: 11, weight: .medium))
            Spacer(minLength: 0)
            Text("\(value) / \(target) g").font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
