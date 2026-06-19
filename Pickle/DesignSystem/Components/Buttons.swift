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

/// White-filled rectangle. One per screen, the single most important action.
struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PickleFont.button())
                .foregroundStyle(Palette.background)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Palette.primary.opacity(enabled ? 1 : 0.4))
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .accessibilityAddTraits(.isButton)
    }
}

/// 1px-outlined rectangle, secondary action.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PickleFont.button())
                .foregroundStyle(Palette.primary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .stroke(Palette.primary.opacity(0.5), lineWidth: Hairline.width)
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
                .foregroundStyle(Palette.primary)
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
