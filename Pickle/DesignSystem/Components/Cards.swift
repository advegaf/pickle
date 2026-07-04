import SwiftUI
import UIKit

// MARK: - Glass card

/// The Glow surface recipe, applied ~15x across the app: flat `surface` fill, a 1px
/// top-edge highlight that fades at the sides, and ONE ambient shadow. Deliberately no
/// Material: cards are glass-LOOK; only the floating bar and sheets get real glass.
struct GlassCard: ViewModifier {
    var radius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        content
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
    }
}

extension View {
    /// The one card surface. Pass a smaller radius for compact cards (concentric rule:
    /// outer = inner + padding).
    func glassCard(radius: CGFloat = Radius.card) -> some View {
        modifier(GlassCard(radius: radius))
    }
}

// MARK: - Imagery

/// Stand-in for treated photography. A dark vertical gradient, plus the subtle 1px white
/// outline that gives images consistent depth on black.
struct DuotonePlaceholder: View {
    var seed: Int = 0

    private var base: Color {
        let tones = [Color(hex: "1C1C1C"), Color(hex: "232323"), Color(hex: "171717"), Color(hex: "262626")]
        return tones[abs(seed) % tones.count]
    }

    var body: some View {
        LinearGradient(
            colors: [base.opacity(0.6), Color.black.opacity(0.95)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(base.opacity(0.25))
    }
}

/// Loads a bundled photo by asset name and applies one consistent in-app duotone treatment
/// (desaturate, lift contrast, deepen toward black). Falls back to the gradient placeholder
/// when the asset is missing, so generated images can be dropped in by name one at a time.
/// See Resources/ImagePrompts.md for the asset names.
struct TreatedImage: View {
    var asset: String?
    var seed: Int = 0

    var body: some View {
        if let asset, UIImage(named: asset) != nil {
            // Color.clear pins the layout size to the container; the image rides in an
            // overlay so scaledToFill can fill and overflow without ballooning the frame.
            // Without this, a portrait source in a short, wide card reports an oversized
            // height and pushes any bottom-aligned overlay (the card title) past the clip.
            Color.clear
                .overlay(
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                )
                .overlay(Color.black.opacity(0.10))
                .clipped()
        } else {
            DuotonePlaceholder(seed: seed)
        }
    }
}

/// 1px low-opacity outline for any image edge (pure white at 10% on dark, never tinted).
struct ImageOutline: ViewModifier {
    var radius: CGFloat = Radius.card
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

extension View {
    func imageOutline(radius: CGFloat = Radius.card) -> some View {
        modifier(ImageOutline(radius: radius))
    }
}

// MARK: - DAILY FUEL card (Home hero)

struct DailyFuelCard: View {
    let consumed: Int
    let target: Int
    let protein: (Int, Int)
    let carbs: (Int, Int)
    let fat: (Int, Int)
    let mealsLogged: Int
    let mealsTotal: Int
    var hasData: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Eyebrow(text: "Daily Fuel")

            HStack(spacing: Spacing.xl) {
                KcalRing(consumed: consumed, target: target, diameter: 132, hasData: hasData)
                VStack(spacing: Spacing.m) {
                    MacroBar(label: "Protein", short: "P", value: protein.0, target: protein.1, tint: Palette.protein)
                    MacroBar(label: "Carbs", short: "C", value: carbs.0, target: carbs.1, tint: Palette.carbs)
                    MacroBar(label: "Fat", short: "F", value: fat.0, target: fat.1, tint: Palette.fat)
                }
            }

            Divider().overlay(Palette.hairline)

            HStack {
                Text(hasData ? "\(consumed) / \(target) cal" : "0 / \(target) cal")
                    .font(PickleFont.caption())
                    .foregroundStyle(Palette.secondary)
                    .monospacedDigit()
                Spacer()
                MealDots(logged: mealsLogged, total: mealsTotal)
            }
        }
        .padding(Spacing.l)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }
}

// MARK: - Milestone banner

struct MilestoneBanner: View {
    let title: String
    let subtitle: String
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Eyebrow(text: "Milestone")
            Text(title)
                .font(PickleFont.display(28))
                .foregroundStyle(Palette.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(PickleFont.body(15))
                .foregroundStyle(Palette.secondary)
            if action != nil {
                Button(action: { action?() }) {
                    HStack(spacing: 6) {
                        Text("View")
                            .font(PickleFont.button(14))
                            .underline()
                        PickleIcon(.arrowRight, size: 12)
                    }
                    .foregroundStyle(Palette.primary)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Photo card (Explore / Coach)

struct PhotoCard: View {
    let title: String
    var subtitle: String? = nil
    var eyebrow: String? = nil
    var seed: Int = 0
    var asset: String? = nil
    var height: CGFloat = 200
    var action: () -> Void = {}

    private let contentMargin: CGFloat = 16   // base inset from the card edge

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                TreatedImage(asset: asset, seed: seed)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .center, endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(PickleFont.label(11))
                            .foregroundStyle(Palette.secondary)
                    }
                    Text(title)
                        .font(PickleFont.heading(19))
                        .foregroundStyle(Palette.primary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(PickleFont.caption())
                            .foregroundStyle(Palette.secondary)
                    }
                }
                .padding(contentMargin)
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .imageOutline()
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([eyebrow, title, subtitle].compactMap { $0 }.joined(separator: ", "))
    }
}

// MARK: - Grouped list (More tab, Home quick links)

/// Leading inset for a row's label past its icon column (horizontal pad + icon width + spacing).
private let listRowLabelInset = Spacing.l + 24 + Spacing.m

/// One navigational row: a thin tinted icon, a label, and a chevron. Group several inside a
/// `GroupedListCard`. Premium and photo-free, the clean alternative to the old image rows.
struct ListRow: View {
    let icon: Glyph
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                PickleIcon(icon, size: 20)
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 24)
                Text(title)
                    .font(PickleFont.bodyMedium(16))
                    .foregroundStyle(Palette.primary)
                Spacer()
                PickleIcon(.chevronRight, size: 13)
                    .foregroundStyle(Palette.tertiary)
            }
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

/// Hairline between grouped rows, inset to align under the label (not the icon), Apple-grade.
struct ListRowDivider: View {
    var body: some View {
        Divider().overlay(Palette.hairline).padding(.leading, listRowLabelInset)
    }
}

/// Wraps a stack of `ListRow`s (with `ListRowDivider`s between) in one rounded surface card.
struct GroupedListCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            DailyFuelCard(consumed: 1150, target: 2200,
                          protein: (85, 140), carbs: (120, 240), fat: (40, 70),
                          mealsLogged: 2, mealsTotal: 4)
            MilestoneBanner(title: "3-day streak", subtitle: "You're building momentum. Keep going.") {}
            PhotoCard(title: "High Protein", subtitle: "24 meals", eyebrow: "Collection", seed: 1)
            GroupedListCard {
                ListRow(icon: .favorite, title: "Favorites")
                ListRowDivider()
                ListRow(icon: .edit, title: "Custom Foods")
            }
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
}
