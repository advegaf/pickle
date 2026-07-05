import SwiftUI

/// Coach: the transparent, adaptive brain of the app. Shows the current plan and the math
/// behind it, the weekly recalibration (with its reasoning), insights, and a recalculate flow.
struct CoachView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var showRecalc = false

    @State private var coachAdvice: String?
    @State private var coachLoading = false
    @State private var coachFailed = false
    @State private var coachReady = false

    private static let adviceKey = "coachAdviceText"
    private static let cacheKeyKey = "coachAdviceCacheKey"

    private var profile: ProfileData { store.profile() }
    private var adaptive: AdaptivePlanEngine.Result { store.adaptiveRecommendation() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Coach")
                    .font(PickleFont.display(34))
                    .foregroundStyle(Palette.primary)
                    .padding(.top, Spacing.s)

                coachCard.pickleEntrance(index: 1)
                heroCard.pickleEntrance(index: 2)
                adaptiveCard.pickleEntrance(index: 3)
                yourPlan.pickleEntrance(index: 4)
                insights.pickleEntrance(index: 5)
                recalcButton.pickleEntrance(index: 6)
                QuoteCarousel().pickleEntrance(index: 7)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.l)
        }
        .background(Palette.background)
        .task { await loadCoach() }
        .sheet(isPresented: $showRecalc) {
            RecalculateSheet().environmentObject(store)
        }
    }

    // MARK: AI coach

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Your coach")
            Group {
                if let advice = coachAdvice {
                    Text(advice)
                        .font(PickleFont.body(16))
                        .foregroundStyle(Palette.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                } else if coachLoading {
                    HStack(spacing: Spacing.m) {
                        DotLoader(size: 26, dot: 6)
                        Text("Reading your week\u{2026}")
                            .font(PickleFont.body(15))
                            .foregroundStyle(Palette.tertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else if coachFailed {
                    Text("Your coach is offline right now. Check back later and it will pick up where your week left off.")
                        .font(PickleFont.body(15))
                        .foregroundStyle(Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Log a few days and your coach reads the patterns in what you eat, then tells you the one thing to focus on next.")
                        .font(PickleFont.body(15))
                        .foregroundStyle(Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .glassCard()
        }
        .animation(Motion.easeOut, value: coachAdvice)
        .animation(Motion.easeOut, value: coachLoading)
    }

    /// Generate (or reuse cached) advice once when Coach first appears. Cached in UserDefaults
    /// keyed by the data signature, so it regenerates at most daily and when the numbers move.
    @MainActor
    private func loadCoach() async {
        guard coachAdvice == nil, !coachLoading else { return }
        let summary = store.coachingSummary()
        guard summary.loggedDays >= 3 else { coachReady = false; return }
        coachReady = true

        let defaults = UserDefaults.standard
        if let cached = defaults.string(forKey: Self.adviceKey), !cached.isEmpty,
           defaults.string(forKey: Self.cacheKeyKey) == summary.cacheKey {
            coachAdvice = cached
            return
        }

        coachLoading = true
        coachFailed = false
        do {
            let advice = try await AICoachingFactory.make().advise(summary.text)
            coachAdvice = advice
            defaults.set(advice, forKey: Self.adviceKey)
            defaults.set(summary.cacheKey, forKey: Self.cacheKeyKey)
        } catch {
            coachFailed = true
        }
        coachLoading = false
    }

    /// The old full-bleed hero, reborn as a rounded photo card (the Explore imagery
    /// pattern) so Coach keeps its editorial soul under the standard tab header.
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            TreatedImage(asset: "coach-hero", seed: 9)
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            Text("Powering precision\nnutrition.")
                .font(PickleFont.display(24))
                .foregroundStyle(Palette.primary)
                .padding(Spacing.l)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .imageOutline()
    }

    // MARK: Adaptive

    private var adaptiveCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Weekly recalibration")

            VStack(alignment: .leading, spacing: Spacing.l) {
                if adaptive.changed, let maintenance = adaptive.estimatedMaintenanceKcal {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        HStack(alignment: .center, spacing: Spacing.s) {
                            targetColumn("Now", profile.targets.kcal, dim: true)
                            PickleIcon(.arrowRight, size: 14)
                                .foregroundStyle(Palette.tertiary)
                            targetColumn("Next week", adaptive.newKcal, dim: false)
                        }
                        Text("Your logged intake and weight trend put your true maintenance near \(maintenance) cal. \(adaptive.reason)")
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .glassCard()
        }
    }

    private func targetColumn(_ label: String, _ kcal: Int, dim: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(PickleFont.label(11))
                .foregroundStyle(Palette.tertiary)
            Text("\(kcal)")
                .font(PickleFont.stat(30))
                .foregroundStyle(dim ? Palette.tertiary : Palette.primary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(kcal)))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Plan transparency

    private var yourPlan: some View {
        let p = profile.planProfile
        let bmr = Int(PlanCalculator.bmr(p).rounded())
        let tdee = Int(PlanCalculator.tdee(p).rounded())
        let adj = Int(PlanCalculator.dailyAdjustment(profile.planGoal).rounded())
        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Your plan, transparent")
            VStack(spacing: 0) {
                mathRow("Base metabolism (BMR)", "\(bmr) cal")
                mathRow("× \(profile.activity.title.lowercased())", "\(tdee) cal")
                mathRow(adj == 0 ? "Maintain" : (adj < 0 ? "Goal deficit" : "Goal surplus"),
                        adj == 0 ? "-" : "\(adj > 0 ? "+" : "")\(adj) cal")
                Divider().overlay(Palette.hairline)
                mathRow("Daily target", "\(profile.targets.kcal) cal", emphasis: true)
            }
            .padding(Spacing.l)
            .glassCard()

            Text(PlanCalculator.basalFormula(p) == .katchMcArdle
                 ? "Calculated with the Katch-McArdle formula from your Apple Health lean body mass, the most accurate basal rate."
                 : "Calculated with Mifflin-St Jeor. Connect Apple Health for a lean-mass-based estimate.")
                .font(PickleFont.caption(12))
                .foregroundStyle(Palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.m) {
                MacroChip(value: "\(profile.targets.proteinG)g", label: "Protein", tint: Palette.protein)
                MacroChip(value: "\(profile.targets.carbsG)g", label: "Carbs", tint: Palette.carbs)
                MacroChip(value: "\(profile.targets.fatG)g", label: "Fat", tint: Palette.fat)
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

    // MARK: Insights

    private var insights: some View {
        let input = store.adaptiveInput()
        let weights = store.weights()
        let trend = weightTrend(weights)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "This week")
            HStack {
                StatBlock(number: input.avgDailyIntakeKcal > 0 ? "\(Int(input.avgDailyIntakeKcal))" : "-",
                          label: "Avg intake")
                StatBlock(number: "\(input.loggedDays)", label: "Days logged")
                StatBlock(number: trend, label: "Weight trend")
            }
        }
    }

    private func weightTrend(_ samples: [WeightSample]) -> String {
        guard let first = samples.first, let last = samples.last, samples.count >= 2 else { return "-" }
        let deltaKg = last.kg - first.kg
        let deltaLb = deltaKg * 2.2046226
        if abs(deltaLb) < 0.3 { return "flat" }
        return String(format: "%@%.1f lb", deltaLb > 0 ? "+" : "", deltaLb)
    }

    private var recalcButton: some View {
        SecondaryButton(title: "Recalculate my plan") { showRecalc = true }
    }
}

/// Page-dotted carousel of nutrition principles. Each visit shows a rotating window of the
/// full set, advancing from a persisted offset, so the leading quote is always fresh and the
/// whole library cycles before anything repeats.
struct QuoteCarousel: View {
    private static let library = [
        "Protein first. Build the rest of the plate around it.",
        "A close estimate logged beats a perfect one skipped.",
        "Believe the weekly trend, not the daily weigh-in.",
        "Sustainable beats aggressive. Every single time.",
        "The streak isn't willpower. It's lowering the cost of the next log.",
        "Fiber is free volume. It fills you up for almost nothing.",
        "You can't out-train a diet you haven't measured.",
        "Hunger is data, not failure. Read it, then adjust.",
        "The best diet is the one you'll still be doing in a year.",
        "Hit protein and fiber, and the rest tends to sort itself out.",
        "Liquid calories are the easiest ones to forget. Log them first.",
        "Progress hides in the average, not the outlier.",
        "Plan the meal you'll actually eat, not the one you wish you would.",
        "One high day doesn't undo a good week. Keep going.",
        "Consistency compounds. Motivation doesn't.",
    ]
    private let window = 5

    @AppStorage("coachQuoteOffset") private var offset = 0
    @State private var index = 0
    @State private var shown: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Principles")
            TabView(selection: $index) {
                ForEach(Array(shown.enumerated()), id: \.offset) { i, q in
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
                ForEach(shown.indices, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Palette.primary : Palette.faint.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .onAppear {
            guard shown.isEmpty else { return }
            let lib = Self.library
            let start = ((offset % lib.count) + lib.count) % lib.count
            shown = (0..<window).map { lib[(start + $0) % lib.count] }
            index = 0
            offset = (start + window) % lib.count   // next Coach visit continues from here
        }
    }
}
