import SwiftUI

/// One macro as a small glass card: sentence-case label, thin progress capsule, grams
/// value with its target. The Glow replacement for the bars-beside-ring layout.
struct MacroCard: View {
    let label: String
    let grams: Int
    let target: Int
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(grams) / Double(target), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(label)
                .font(PickleFont.label())
                .foregroundStyle(Palette.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.faint.opacity(0.5))
                    Capsule().fill(tint)
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 3 : 0))
                        .animation(reduceMotion ? nil : Motion.ringGrow, value: fraction)
                }
            }
            .frame(height: 4)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(grams)g")
                    .font(PickleFont.bodyMedium(17))
                    .foregroundStyle(Palette.primary)
                    .monospacedDigit()
                Text("of \(target)g")
                    .font(PickleFont.caption(11))
                    .foregroundStyle(Palette.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(Spacing.m + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(grams) of \(target) grams")
    }
}

/// The 3-up macro row. Collapses to a vertical stack at accessibility type sizes so the
/// cards never truncate.
struct MacroCardRow: View {
    let consumed: MacroTargets
    let targets: MacroTargets

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let cards = Group {
            MacroCard(label: "Protein", grams: consumed.proteinG, target: targets.proteinG, tint: Palette.protein)
            MacroCard(label: "Carbs", grams: consumed.carbsG, target: targets.carbsG, tint: Palette.carbs)
            MacroCard(label: "Fat", grams: consumed.fatG, target: targets.fatG, tint: Palette.fat)
        }
        if typeSize.isAccessibilitySize {
            VStack(spacing: Spacing.m) { cards }
        } else {
            HStack(spacing: Spacing.m) { cards }
        }
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        MacroCardRow(
            consumed: MacroTargets(kcal: 1023, proteinG: 86, carbsG: 142, fatG: 41),
            targets: MacroTargets(kcal: 2000, proteinG: 180, carbsG: 220, fatG: 70)
        )
        .padding(Spacing.screen)
    }
}
