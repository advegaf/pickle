import SwiftUI

/// The floating action pill (the Equinox "Check in" → Pickle "Log"). White, rounded,
/// sits bottom-right with a soft layered shadow so it floats above scrolling content.
struct FloatingPill: View {
    var title: String = "Log"
    var icon: Glyph = .add
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                PickleIcon(icon, size: 15)
                Text(title)
                    .font(PickleFont.button(15))
            }
            .foregroundStyle(Palette.background)
            .padding(.horizontal, Spacing.l)
            .frame(height: 48)
            .background(Palette.primary)
            .clipShape(Capsule())
            // Layered shadows read more natural than a single hard one.
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        Palette.background.ignoresSafeArea()
        FloatingPill { }
            .padding(Spacing.l)
    }
}
