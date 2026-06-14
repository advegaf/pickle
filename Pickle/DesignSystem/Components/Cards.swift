import SwiftUI

// MARK: - Image placeholder (real duotone treatment lands in Phase 15)

/// Stand-in for treated photography. A dark vertical gradient with a faint grain feel,
/// plus the subtle 1px white outline that gives images consistent depth on black.
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

/// 1px low-opacity outline for any image edge (pure white at 10% on dark — never tinted).
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
                Text(hasData ? "\(consumed) / \(target) kcal" : "— / \(target) kcal")
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
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .medium))
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
    var height: CGFloat = 200
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                DuotonePlaceholder(seed: seed)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .center, endPoint: .bottom
                )
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(PickleFont.eyebrow(10))
                        .tracking(2)
                        .foregroundStyle(Palette.primary.opacity(0.9))
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 16)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .padding(.leading, Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 4) {
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
                .padding(Spacing.m)
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

// MARK: - Image row (More tab)

struct ImageRow: View {
    let title: String
    var seed: Int = 0
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                DuotonePlaceholder(seed: seed)
                LinearGradient(colors: [.black.opacity(0.7), .clear],
                               startPoint: .leading, endPoint: .trailing)
                Text(title)
                    .font(PickleFont.heading(19))
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, Spacing.l)
            }
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .imageOutline()
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
    }
}

// MARK: - Quick link row (thumbnail + label + chevron)

struct QuickLinkRow: View {
    let title: String
    var systemImage: String? = nil
    var seed: Int = 0
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    DuotonePlaceholder(seed: seed)
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(Palette.primary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                .imageOutline(radius: Radius.button)

                Text(title)
                    .font(PickleFont.bodyMedium())
                    .foregroundStyle(Palette.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.tertiary)
            }
            .frame(minHeight: 56)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
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
            ImageRow(title: "Club Locations", seed: 2)
            QuickLinkRow(title: "Favorites", systemImage: "heart", seed: 3)
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
}
