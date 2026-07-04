import SwiftUI

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

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.m) {
                MacroBar(label: "Protein", short: "P", value: 85, target: 140, tint: Palette.protein)
                MacroBar(label: "Carbs", short: "C", value: 120, target: 240, tint: Palette.carbs)
                MacroBar(label: "Fat", short: "F", value: 40, target: 70, tint: Palette.fat)
            }
            MacroLine(macros: MacroTargets(kcal: 520, proteinG: 30, carbsG: 40, fatG: 20))
        }
        .padding(Spacing.screen)
    }
}
