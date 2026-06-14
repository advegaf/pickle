import SwiftUI

/// Coach: the transparent, adaptive brain of the app. Shows the current plan and the math
/// behind it, the weekly recalibration (with its reasoning), insights, and a recalculate flow.
struct CoachView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var showRecalc = false

    private var profile: ProfileData { store.profile() }
    private var adaptive: AdaptivePlanEngine.Result { store.adaptiveRecommendation() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                hero
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    adaptiveCard
                    yourPlan
                    insights
                    recalcButton
                    QuoteCarousel()
                }
                .padding(.horizontal, Spacing.screen)
            }
            .padding(.bottom, 120)
        }
        .background(Palette.background)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showRecalc) {
            RecalculateSheet().environmentObject(store)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            DuotonePlaceholder(seed: 9)
            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: Spacing.s) {
                Eyebrow(text: "Coach", color: Palette.secondary)
                Text("Powering precision\nnutrition.")
                    .font(PickleFont.display(30))
                    .foregroundStyle(Palette.primary)
            }
            .padding(Spacing.screen)
            .padding(.bottom, Spacing.s)
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    // MARK: Adaptive

    private var adaptiveCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Eyebrow(text: "Weekly recalibration")

            if adaptive.changed, let maintenance = adaptive.estimatedMaintenanceKcal {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.l) {
                        targetColumn("Now", profile.targets.kcal, dim: true)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.tertiary)
                        targetColumn("Next week", adaptive.newKcal, dim: false)
                    }
                    Text("Your logged intake and weight trend put your true maintenance near \(maintenance) kcal. \(adaptive.reason)")
                        .font(PickleFont.body(14))
                        .foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(title: "Apply new target") {
                        store.applyAdaptive(adaptive); Haptics.celebrate()
                    }
                }
            } else {
                Text(adaptive.reason)
                    .font(PickleFont.body(15))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.l)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private func targetColumn(_ label: String, _ kcal: Int, dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PickleFont.eyebrow(10)).tracking(1.5)
                .foregroundStyle(Palette.tertiary).textCase(.uppercase)
            Text("\(kcal)")
                .font(PickleFont.stat(30))
                .foregroundStyle(dim ? Palette.tertiary : Palette.primary)
                .monospacedDigit()
        }
    }

    // MARK: Plan transparency

    private var yourPlan: some View {
        let p = profile.planProfile
        let bmr = Int(PlanCalculator.bmr(p).rounded())
        let tdee = Int(PlanCalculator.tdee(p).rounded())
        let adj = Int(PlanCalculator.dailyAdjustment(profile.planGoal).rounded())
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Your plan, transparent")
            VStack(spacing: 0) {
                mathRow("Base metabolism (BMR)", "\(bmr) kcal")
                mathRow("× \(profile.activity.title.lowercased())", "\(tdee) kcal")
                mathRow(adj == 0 ? "Maintain" : (adj < 0 ? "Goal deficit" : "Goal surplus"),
                        adj == 0 ? "—" : "\(adj > 0 ? "+" : "")\(adj) kcal")
                Divider().overlay(Palette.hairline)
                mathRow("Daily target", "\(profile.targets.kcal) kcal", emphasis: true)
            }
            .padding(Spacing.l)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))

            HStack(spacing: Spacing.m) {
                macroChip("Protein", profile.targets.proteinG)
                macroChip("Carbs", profile.targets.carbsG)
                macroChip("Fat", profile.targets.fatG)
            }
        }
    }

    private func mathRow(_ label: String, _ value: String, emphasis: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasis ? PickleFont.bodyMedium(15) : PickleFont.body(15))
                .foregroundStyle(emphasis ? Palette.primary : Palette.secondary)
            Spacer()
            Text(value)
                .font(emphasis ? PickleFont.bodyMedium(15) : PickleFont.body(15))
                .foregroundStyle(emphasis ? Palette.primary : Palette.secondary)
                .monospacedDigit()
        }
        .frame(minHeight: 40)
    }

    private func macroChip(_ label: String, _ grams: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(grams)g").font(PickleFont.bodyMedium(17)).foregroundStyle(Palette.primary).monospacedDigit()
            Text(label).font(PickleFont.caption(11)).foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    // MARK: Insights

    private var insights: some View {
        let input = store.adaptiveInput()
        let weights = store.weights()
        let trend = weightTrend(weights)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "This week")
            HStack {
                StatBlock(number: input.avgDailyIntakeKcal > 0 ? "\(Int(input.avgDailyIntakeKcal))" : "—",
                          label: "Avg intake")
                StatBlock(number: "\(input.loggedDays)", label: "Days logged")
                StatBlock(number: trend, label: "Weight trend")
            }
        }
    }

    private func weightTrend(_ samples: [WeightSample]) -> String {
        guard let first = samples.first, let last = samples.last, samples.count >= 2 else { return "—" }
        let deltaKg = last.kg - first.kg
        let deltaLb = deltaKg * 2.2046226
        if abs(deltaLb) < 0.3 { return "flat" }
        return String(format: "%@%.1f lb", deltaLb > 0 ? "+" : "", deltaLb)
    }

    private var recalcButton: some View {
        SecondaryButton(title: "Recalculate my plan") { showRecalc = true }
    }
}

/// Page-dotted carousel of nutrition principles.
struct QuoteCarousel: View {
    private let quotes = [
        "Protein first. Build the rest of the plate around it.",
        "A close estimate logged beats a perfect one skipped.",
        "Believe the weekly trend, not the daily weigh-in.",
        "Sustainable beats aggressive. Every single time.",
        "The streak isn't willpower. It's lowering the cost of the next log.",
    ]
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Principles")
            TabView(selection: $index) {
                ForEach(Array(quotes.enumerated()), id: \.offset) { i, q in
                    Text("\u{201C}\(q)\u{201D}")
                        .font(PickleFont.display(22))
                        .foregroundStyle(Palette.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, Spacing.l)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 120)

            HStack(spacing: 6) {
                ForEach(quotes.indices, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Palette.primary : Palette.faint.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
}
