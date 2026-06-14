import SwiftUI

/// Shared layout for a data-collection step: an all-caps display title, optional subtitle,
/// scrollable content, and a pinned primary button.
struct OnboardingScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var ctaTitle: String = "Continue"
    var ctaEnabled: Bool = true
    let onContinue: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(title.uppercased())
                            .font(PickleFont.onboarding(32))
                            .foregroundStyle(Palette.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(PickleFont.body(15))
                                .foregroundStyle(Palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    content()
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }

            PrimaryButton(title: ctaTitle, enabled: ctaEnabled, action: onContinue)
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.l)
        }
    }
}

/// A tappable selection card: title + optional detail + a check when selected.
struct SelectableCard: View {
    let title: String
    var detail: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PickleFont.bodyMedium(16))
                        .foregroundStyle(Palette.primary)
                    if let detail {
                        Text(detail)
                            .font(PickleFont.caption())
                            .foregroundStyle(Palette.tertiary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? Palette.primary : Palette.faint, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle().fill(Palette.primary).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.background)
                    }
                }
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .stroke(selected ? Palette.primary.opacity(0.6) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Simple two-or-more option segmented control on the dark surface.
struct SegmentedPicker<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let active = option.value == selection
                Button {
                    if selection != option.value { selection = option.value; Haptics.select() }
                } label: {
                    Text(option.label)
                        .font(PickleFont.button(15))
                        .foregroundStyle(active ? Palette.background : Palette.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(active ? Palette.primary : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(3)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button + 3))
    }
}
