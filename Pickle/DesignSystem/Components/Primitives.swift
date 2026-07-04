import SwiftUI

// MARK: - Section label

/// Sentence-case section label, the Glow replacement for the old ALL-CAPS eyebrow.
struct SectionLabel: View {
    let text: String
    var color: Color = Palette.secondary

    var body: some View {
        Text(sentenceCased(text))
            .font(PickleFont.label())
            .foregroundStyle(color)
            .accessibilityLabel(text)
    }

    /// Call sites historically passed shouting strings ("TODAY'S MEALS"); normalize any
    /// all-caps input to sentence case so no screen shouts during the migration.
    private func sentenceCased(_ s: String) -> String {
        guard s == s.uppercased(), s.count > 1 else { return s }
        return s.prefix(1).uppercased() + s.dropFirst().lowercased()
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

/// The reference's loading animation, four dots orbiting. Honors Reduce Motion
/// (falls back to a gentle opacity pulse).
struct DotLoader: View {
    var size: CGFloat = 56
    var dot: CGFloat = 12
    /// Flip to true when the work finishes: the four orbiting dots spiral inward and merge
    /// into a single dot. Caller should pause briefly after setting this so the merge plays.
    var done: Bool = false
    @State private var angle: Double = 0
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle().fill(Palette.accent)
                            .frame(width: dot, height: dot)
                            .opacity(done && i != 0 ? 0 : 1)
                    }
                }
                .opacity(done ? 1 : (pulse ? 0.4 : 1))
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                .animation(.easeOut(duration: 0.25), value: done)
                .onAppear { pulse = true }
            } else {
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: dot, height: dot)
                            .scaleEffect(done && i == 0 ? 1.3 : 1)
                            .opacity(done && i != 0 ? 0 : 1)
                            .offset(y: done ? 0 : -size / 2)   // converge to center when done
                            .rotationEffect(.degrees(Double(i) / 4 * 360))
                    }
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))   // keeps spinning; invisible once dots are centered
                .animation(Motion.lively, value: done)
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }
            }
        }
        .accessibilityLabel(done ? "Done" : "Loading")
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
                .glassCard(radius: Radius.button)
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(spacing: Spacing.xl) {
            SectionLabel(text: "Milestone")
            HStack {
                StatBlock(number: "3", label: "Day streak")
                StatBlock(number: "12", label: "Days logged")
                StatBlock(number: "1,980", label: "Avg cal")
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
