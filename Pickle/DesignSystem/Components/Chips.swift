import SwiftUI

/// The persistent streak flame chip in the Home header. Backed by `StreakCalculator`;
/// counts animate with a numeric transition.
struct StreakChip: View {
    let streak: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(streak > 0 ? Palette.accent : Palette.tertiary)
            Text("\(streak)")
                .font(PickleFont.bodyMedium(14))
                .foregroundStyle(Palette.primary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(streak)))
                .animation(reduceMotion ? nil : Motion.lively, value: streak)
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: 36)
        .background(Palette.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassEdge, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streak == 1 ? "1 day streak" : "\(streak) day streak")
    }
}

/// The Home header bell. The red dot means a reminder fired today for a meal that is
/// still unlogged; it clears by logging (or at day rollover), not by opening the sheet.
struct BellChip: View {
    let missed: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .frame(width: 36, height: 36)
                .background(Palette.surface)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Palette.glassEdge, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if missed > 0 {
                        Circle()
                            .fill(Palette.over)
                            .frame(width: 8, height: 8)
                            .offset(x: -2, y: 2)
                    }
                }
        }
        .buttonStyle(.pressable)
        .frame(width: 44, height: 44)
        .accessibilityLabel(missed > 0 ? "Reminders, \(missed) missed" : "Reminders, none missed")
    }
}

/// One macro as a small stat chip ("142g" over "Carbs"), used in plan and summary
/// cards (Coach, Profile, day detail). Replaces three hand-rolled copies.
struct MacroChip: View {
    let value: String
    let label: String
    var tint: Color = Palette.primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PickleFont.bodyMedium(16))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(PickleFont.caption(11))
                .foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
        .background(Palette.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.chip))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.l) {
            HStack {
                StreakChip(streak: 13)
                StreakChip(streak: 0)
                BellChip(missed: 2) {}
                BellChip(missed: 0) {}
            }
            HStack(spacing: Spacing.m) {
                MacroChip(value: "180g", label: "Protein", tint: Palette.protein)
                MacroChip(value: "220g", label: "Carbs", tint: Palette.carbs)
                MacroChip(value: "70g", label: "Fat", tint: Palette.fat)
            }
        }
        .padding(Spacing.screen)
    }
}
