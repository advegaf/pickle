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

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        HStack {
            StreakChip(streak: 13)
            StreakChip(streak: 0)
        }
    }
}
