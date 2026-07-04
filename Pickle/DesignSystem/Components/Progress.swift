import SwiftUI

// MARK: - Kcal ring (the at-a-glance hero)

/// Continuous progress ring with the remaining number at its center. Used on Home's
/// DAILY FUEL card and in the widget. Never segmented, kcal is a continuous quantity.
struct KcalRing: View {
    let consumed: Int
    let target: Int
    var lineWidth: CGFloat = 10
    var diameter: CGFloat = 168
    /// When false (first-run, no target yet), shows an em dash instead of a number.
    var hasData: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var remaining: Int { max(target - consumed, 0) }
    private var over: Int { max(consumed - target, 0) }
    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(consumed) / Double(target), 1)
    }
    /// The magnitude in the center: calories left, or once exceeded, how many calories over.
    private var centerValue: Int { over > 0 ? over : remaining }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.faint.opacity(0.45), lineWidth: lineWidth)

            // No draw-in: the arc sits at its value on appear and only eases (Motion.ringGrow)
            // when the value changes (a new log).
            Circle()
                .trim(from: 0, to: hasData ? fraction : 0)
                .stroke(
                    over > 0 ? Palette.over : Palette.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : Motion.ringGrow, value: fraction)
                .animation(reduceMotion ? nil : Motion.easeOut, value: over > 0)

            VStack(spacing: 2) {
                Text(hasData ? "\(centerValue)" : "-")
                    .font(PickleFont.stat(min(diameter * 0.26, 44)))
                    .foregroundStyle(over > 0 ? Palette.over : Palette.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(centerValue)))
                    .animation(reduceMotion ? nil : Motion.ringGrow, value: centerValue)
                    .animation(reduceMotion ? nil : Motion.easeOut, value: over > 0)
                Text(over > 0 ? "over" : "left")
                    .font(PickleFont.caption(11))
                    .foregroundStyle(over > 0 ? Palette.over : Palette.tertiary)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories")
        .accessibilityValue(
            hasData
            ? "\(consumed) of \(target), \(over > 0 ? "\(over) over" : "\(remaining) remaining")"
            : "No target set yet"
        )
    }
}

// MARK: - Macro bar (density)

/// Thin continuous bar for a single macro. Used in lists and detail, never as a hero.
struct MacroBar: View {
    let label: String          // "Protein"
    let short: String          // "P"
    let value: Int             // grams consumed
    let target: Int            // grams target
    var tint: Color = Palette.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(value) / Double(target), 1)
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text(short)
                .font(PickleFont.caption(11))
                .foregroundStyle(Palette.tertiary)
                .frame(width: 12, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.faint.opacity(0.35))
                    Capsule().fill(tint)
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 3 : 0))
                        .animation(reduceMotion ? nil : Motion.ringGrow, value: fraction)
                }
            }
            .frame(height: 4)

            Text("\(value)/\(target)")
                .font(PickleFont.caption(12))
                .foregroundStyle(Palette.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) of \(target) grams")
    }
}

// MARK: - Macro line (inline P/C/F summary)

/// Compact "P 30  C 40  F 20" line with each letter tinted in its macro color and no separator
/// dot. Used under meal cards / detail rows.
struct MacroLine: View {
    let macros: MacroTargets

    var body: some View {
        HStack(spacing: 14) {
            macro("P", macros.proteinG, Palette.protein)
            macro("C", macros.carbsG, Palette.carbs)
            macro("F", macros.fatG, Palette.fat)
        }
        .font(PickleFont.caption(12))
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Protein \(macros.proteinG), carbs \(macros.carbsG), fat \(macros.fatG) grams")
    }

    private func macro(_ letter: String, _ grams: Int, _ tint: Color) -> Text {
        Text("\(Text(letter).foregroundColor(tint))\(Text(" \(grams)").foregroundColor(Palette.secondary))")
    }
}

// MARK: - Meal dots (discrete count)

/// Discrete "meals logged" dots, ●●○○. The honest use of segmentation: a countable thing.
struct MealDots: View {
    let logged: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < logged ? Palette.accent : Palette.faint.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Meals logged")
        .accessibilityValue("\(logged) of \(total)")
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.xl) {
            KcalRing(consumed: 1150, target: 2200)
            VStack(spacing: Spacing.m) {
                MacroBar(label: "Protein", short: "P", value: 85, target: 140, tint: Palette.protein)
                MacroBar(label: "Carbs", short: "C", value: 120, target: 240, tint: Palette.carbs)
                MacroBar(label: "Fat", short: "F", value: 40, target: 70, tint: Palette.fat)
            }
            MealDots(logged: 2, total: 4)
        }
        .padding(Spacing.screen)
    }
}
