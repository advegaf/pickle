import SwiftUI

/// Tappable citations for the plan math (App Review guideline 1.4.1: health calculations must
/// cite their sources). Reused everywhere a calorie or macro target is explained: Coach's plan
/// transparency, the onboarding plan review, Goals & Plan, and About.
struct PlanSources: View {
    /// Tighter variant for sheets and onboarding (smaller gaps, no preamble line).
    var compact: Bool = false
    @Environment(\.openURL) private var openURL

    struct Source: Identifiable {
        let title: String
        let url: String
        var id: String { url }
    }

    /// Each entry cites a formula actually used in PlanCalculator / the macro targets.
    static let all: [Source] = [
        .init(title: "Mifflin & St Jeor, Am J Clin Nutr 1990 (BMR equation)",
              url: "https://pubmed.ncbi.nlm.nih.gov/2305711/"),
        .init(title: "McArdle, Katch & Katch, Exercise Physiology (lean-mass BMR)",
              url: "https://www.ncbi.nlm.nih.gov/books/NBK278961/"),
        .init(title: "FAO/WHO/UNU Human Energy Requirements (activity levels)",
              url: "https://www.fao.org/4/y5686e/y5686e00.htm"),
        .init(title: "U.S. Dietary Guidelines (macronutrient ranges)",
              url: "https://www.dietaryguidelines.gov/"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Spacing.xs : Spacing.s) {
            SectionLabel(text: "Sources", color: Palette.tertiary)
            if !compact {
                Text("Pickle's targets are estimates from published equations, not medical advice.")
                    .font(PickleFont.caption(12))
                    .foregroundStyle(Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Self.all) { source in
                    Button {
                        if let url = URL(string: source.url) { openURL(url) }
                    } label: {
                        Text(source.title)
                            .font(PickleFont.caption(12))
                            .foregroundStyle(Palette.secondary)
                            .underline()
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 40, alignment: .leading)   // hit area
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Source: \(source.title)")
                    .accessibilityAddTraits(.isLink)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Palette.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: Spacing.xl) {
            PlanSources()
            Divider().overlay(Palette.hairline)
            PlanSources(compact: true)
        }
        .padding(Spacing.screen)
    }
}
