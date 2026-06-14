import SwiftUI

// MARK: - Eyebrow

/// ALL-CAPS wide-tracked micro label. At accessibility text sizes the tracking is
/// reduced so it doesn't overflow. Decorative vertical variant used only on photo cards.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.tertiary
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(text.uppercased())
            .font(PickleFont.eyebrow())
            .tracking(typeSize.isAccessibilitySize ? 1 : 2.5)
            .foregroundStyle(color)
            .accessibilityLabel(text)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(PickleFont.heading())
            .foregroundStyle(Palette.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stat block (Activity "Your Stats")

struct StatBlock: View {
    let number: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(number)
                .font(PickleFont.stat(34))
                .foregroundStyle(Palette.primary)
                .monospacedDigit()
            Text(label)
                .font(PickleFont.caption())
                .foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(number)")
    }
}

// MARK: - 4-dot orbit loader

/// The reference's loading animation — four dots orbiting. Honors Reduce Motion
/// (falls back to a gentle opacity pulse).
struct DotLoader: View {
    var size: CGFloat = 56
    var dot: CGFloat = 12
    @State private var angle: Double = 0
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle().fill(Palette.primary).frame(width: dot, height: dot)
                    }
                }
                .opacity(pulse ? 0.4 : 1)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            } else {
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Palette.primary)
                            .frame(width: dot, height: dot)
                            .offset(y: -size / 2)
                            .rotationEffect(.degrees(Double(i) / 4 * 360))
                    }
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))
                .onAppear {
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }
            }
        }
        .accessibilityLabel("Loading")
    }
}

// MARK: - Category button (Explore "Browse by category")

struct CategoryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PickleFont.bodyMedium(15))
                .foregroundStyle(Palette.primary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.xl) {
            Eyebrow(text: "Milestone")
            HStack {
                StatBlock(number: "3", label: "Day streak")
                StatBlock(number: "12", label: "Days logged")
                StatBlock(number: "1,980", label: "Avg kcal")
            }
            DotLoader()
            HStack(spacing: Spacing.m) {
                CategoryButton(title: "High Protein") {}
                CategoryButton(title: "Under 500") {}
            }
        }
        .padding(Spacing.screen)
    }
}
