import SwiftUI

// MARK: - Press feedback

/// Scale-on-press (0.96), the universal tactile feedback for any pressable surface.
/// Respects Reduce Motion (drops the scale, keeps a subtle opacity dim).
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Primary / Secondary / Text

/// White pill, one per screen, the single most important action. Text in `onAccent`
/// (near-black green) so the pill reads as part of the Glow family, not a stark cutout.
struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PickleFont.button())
                .foregroundStyle(Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.white.opacity(enabled ? 1 : 0.4))
                .clipShape(Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .accessibilityAddTraits(.isButton)
    }
}

/// Glass pill, secondary action: surface fill with the glass top-edge highlight.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PickleFont.button())
                .foregroundStyle(Palette.primary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Palette.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.03)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.pressable)
    }
}

/// Underlined text link, tertiary action.
struct TextLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PickleFont.button(14))
                .foregroundStyle(Palette.accent)
                .underline()
                .frame(minHeight: 44) // hit area
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.l) {
            PrimaryButton(title: "Continue") {}
            PrimaryButton(title: "Disabled", enabled: false) {}
            SecondaryButton(title: "Create custom food") {}
            TextLink(title: "Skip for now") {}
        }
        .padding(Spacing.screen)
    }
}
