import SwiftUI
import WidgetKit

// Compiled into BOTH the widget extension and the app. The widget renders these inside its
// timeline entry views; the app renders them in a DEBUG-only gallery (`--open widgets`) so the
// layouts can be screenshot-verified without adding the widgets to the springboard by hand.

// Widget palette, derived from the shared PaletteValues so it can never drift from the app.
enum W {
    static let bg = Color(hex: PaletteValues.background)
    static let primary = Color(hex: PaletteValues.primary)
    static let secondary = Color(hex: PaletteValues.secondary)
    static let tertiary = Color(hex: PaletteValues.tertiary)
    static let faint = Color(hex: PaletteValues.faint)
    static let accent = Color(hex: PaletteValues.accent)
    static let over = Color(hex: PaletteValues.over)
    static let protein = Color(hex: PaletteValues.protein)
    static let carbs = Color(hex: PaletteValues.carbs)
    static let fat = Color(hex: PaletteValues.fat)
}

// MARK: - Building blocks

/// The mini arc gauge: the app's 270-degree hero arc at widget scale, flat teal (no
/// glow, WidgetKit rendering cost). `tint` lets the Macros widget ring protein.
struct RingMini: View {
    let fraction: Double
    let lineWidth: CGFloat
    var tint: Color = W.accent

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(W.faint.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
        }
    }
}

/// Calorie arc. Same progressive ramp as the app's hero gauge (flat, no glow).
struct KcalRingMini: View {
    let fraction: Double
    let lineWidth: CGFloat
    var over: Bool = false
    var body: some View {
        RingMini(fraction: fraction, lineWidth: lineWidth,
                 tint: over ? W.over : ArcRamp.color(fraction: fraction))
    }
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
                    Text("\(snap.consumedKcal)")
                        .font(.system(size: 21, weight: .semibold)).foregroundStyle(W.primary).monospacedDigit()
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Text("of \(snap.targetKcal)")
                        .font(.system(size: 8, weight: .medium)).foregroundStyle(W.tertiary).monospacedDigit()
                }
                .padding(.horizontal, 12)
            }
            .frame(width: 92, height: 92)

            if !small {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today").font(.system(size: 10, weight: .medium)).foregroundStyle(W.tertiary)
                    MacroBarMini(short: "P", value: snap.proteinG, target: snap.proteinTarget, tint: W.protein)
                    MacroBarMini(short: "C", value: snap.carbsG, target: snap.carbsTarget, tint: W.carbs)
                    MacroBarMini(short: "F", value: snap.fatG, target: snap.fatTarget, tint: W.fat)
                    Text(snap.isOver ? "\(snap.overKcal) over goal" : "\(snap.remainingKcal) left")
                        .font(.system(size: 11)).foregroundStyle(snap.isOver ? W.over : W.secondary).monospacedDigit()
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
            Text("Today").font(.system(size: 11, weight: .medium)).foregroundStyle(W.tertiary)
            HStack(spacing: 18) {
                ZStack {
                    KcalRingMini(fraction: snap.fraction, lineWidth: 10, over: snap.isOver)
                    VStack(spacing: 0) {
                        Text("\(snap.consumedKcal)")
                            .font(.system(size: 28, weight: .semibold)).foregroundStyle(W.primary).monospacedDigit()
                            .minimumScaleFactor(0.7).lineLimit(1)
                        Text("of \(snap.targetKcal)")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(W.tertiary).monospacedDigit()
                    }
                    .padding(.horizontal, 14)
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
                Text(snap.isOver ? "\(snap.overKcal) over goal" : "\(snap.remainingKcal) left")
                    .font(.system(size: 12)).foregroundStyle(snap.isOver ? W.over : W.secondary).monospacedDigit()
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
            RingMini(fraction: snap.fraction, lineWidth: 5, tint: .white)
            VStack(spacing: 0) {
                Text("\(snap.consumedKcal)")
                    .font(.system(size: 16, weight: .bold)).monospacedDigit()
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(snap.isOver ? "over" : "of \(snap.targetKcal)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 8)
            .widgetAccentable()
        }
    }
}

struct CalorieRectangular: View {
    let snap: DiarySnapshot
    var body: some View {
        HStack(spacing: 10) {
            RingMini(fraction: snap.fraction, lineWidth: 4, tint: .white).frame(width: 34, height: 34).widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(snap.consumedKcal)")
                        .font(.system(size: 20, weight: .bold)).monospacedDigit().widgetAccentable()
                    Text(snap.isOver ? "cal, \(snap.overKcal) over" : "of \(snap.targetKcal) cal")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).monospacedDigit()
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
        Label(snap.isOver ? "\(snap.consumedKcal) cal, \(snap.overKcal) over"
                          : "\(snap.consumedKcal) of \(snap.targetKcal) cal",
              systemImage: "flame.fill")
    }
}

// MARK: - Macros widget views

struct MacrosHome: View {
    let snap: DiarySnapshot
    let small: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 10 : 12) {
            Text("Macros").font(.system(size: 10, weight: .medium)).foregroundStyle(W.tertiary)
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
