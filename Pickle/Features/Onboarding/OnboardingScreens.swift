import SwiftUI

// MARK: - Hero

struct HeroStep: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            TreatedImage(asset: "onboarding-hero", seed: 7).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.xl) {
                Spacer()
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Wordmark(size: 16)
                    Text("FUEL YOUR\nPURSUIT.")
                        .font(PickleFont.onboarding(40))
                        .foregroundStyle(Palette.primary)
                        .lineSpacing(2)
                }
                PrimaryButton(title: "Get started", action: onContinue)
            }
            .padding(Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
    }
}

// MARK: - Privacy

struct PrivacyStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: Spacing.l) {
                PickleIcon(.shield, size: 34)
                    .foregroundStyle(Palette.primary)
                Text("Your data stays\nyours.")
                    .font(PickleFont.display(32))
                    .foregroundStyle(Palette.primary)
                Text("Your diary and health data live on your device and sync privately through your iCloud. No account, no servers, no selling your numbers.")
                    .font(PickleFont.body(16))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Photos you send to AI logging are the one exception, those are processed to estimate macros, then discarded.")
                    .font(PickleFont.caption())
                    .foregroundStyle(Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            PrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Connect Apple Health

/// The smart-setup step. Pulls real body data and movement from Apple Health and prefills the
/// plan, with a clean manual fallback when Health is unavailable or denied.
struct HealthConnectStep: View {
    @Binding var draft: ProfileData
    let onContinue: () -> Void

    @StateObject private var health = HealthKitService.shared
    @State private var working = false
    @State private var imported: BodyProfile?

    private var connected: Bool { imported != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: Spacing.l) {
                PickleIcon(.health, size: 40)
                    .foregroundStyle(Palette.primary)
                Text(connected ? "You're all set." : "Set up\nautomatically.")
                    .font(PickleFont.display(32))
                    .foregroundStyle(Palette.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(connected
                     ? "Pickle pulled your numbers from Apple Health and tuned your plan. You can adjust anything next."
                     : "Connect Apple Health and Pickle builds your plan from your real weight, body composition, and movement. The smartest setup in the market.")
                    .font(PickleFont.body(16))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let bp = imported { importedSummary(bp) }
            }
            Spacer()
            VStack(spacing: Spacing.s) {
                PrimaryButton(title: buttonTitle, enabled: !working) {
                    if connected { onContinue() } else { connect() }
                }
                if !connected && !working {
                    TextLink(title: "Set up manually") { onContinue() }
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.xl)
    }

    private var buttonTitle: String {
        if working { return "Connecting…" }
        return connected ? "Continue" : "Connect Apple Health"
    }

    private func importedSummary(_ bp: BodyProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let w = bp.weightKg { importedRow("Weight", String(format: "%.0f lb", w * 2.2046226)) }
            if let l = bp.leanMassKg { importedRow("Lean mass", String(format: "%.0f lb", l * 2.2046226)) }
            if let act = bp.inferredActivity { importedRow("Activity", act.title) }
            if let steps = bp.avgDailySteps { importedRow("Daily steps", "\(Int(steps))") }
        }
        .padding(.top, Spacing.s)
    }

    private func importedRow(_ label: String, _ value: String) -> some View {
        HStack {
            PickleIcon(.check, size: 12)
                .foregroundStyle(Palette.success)
            Text(label).font(PickleFont.caption()).foregroundStyle(Palette.tertiary)
            Spacer()
            Text(value).font(PickleFont.caption()).foregroundStyle(Palette.secondary).monospacedDigit()
        }
    }

    private func connect() {
        working = true
        Task {
            _ = await health.requestAuthorization()
            let bp = await health.fetchBodyProfile()
            draft.merge(health: bp)
            working = false
            if bp.isEmpty {
                // Nothing came back (simulator, or read denied). Proceed to manual entry.
                onContinue()
            } else {
                imported = bp
                Haptics.confirm()
            }
        }
    }
}

extension ProfileData {
    /// Fill in whatever Apple Health provided, leaving the rest at defaults.
    mutating func merge(health bp: BodyProfile) {
        if let w = bp.weightKg { weightKg = w }
        if let h = bp.heightCm { heightCm = h }
        if let l = bp.leanMassKg { leanMassKg = l }
        if let s = bp.sex { sex = s }
        if let a = bp.age { age = a }
        if let act = bp.inferredActivity { activity = act }
    }
}

// MARK: - Name

struct NameStep: View {
    @Binding var name: String
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(title: "Let's build your plan.",
                           subtitle: "First, what should we call you?",
                           ctaEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                           onContinue: onContinue) {
            UnderlineField(label: "First name", text: $name, contentType: .givenName, submitLabel: .done)
        }
    }
}

// MARK: - Body stats

struct BodyStatsStep: View {
    @Binding var draft: ProfileData
    @Binding var imperial: Bool
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(title: "A bit about you.",
                           subtitle: "This sets your starting calorie and macro targets.",
                           onContinue: onContinue) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Eyebrow(text: "Sex")
                    SegmentedPicker(options: [(Sex.male, "Male"), (Sex.female, "Female")],
                                    selection: $draft.sex)
                }

                UtilityStepper(label: "Age", value: $draft.age, step: 1, range: 13...100, unit: "years")

                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack {
                        Eyebrow(text: "Units")
                        Spacer()
                        SegmentedPicker(options: [(true, "Imperial"), (false, "Metric")],
                                        selection: $imperial)
                            .frame(width: 180)
                    }
                }

                if imperial {
                    ImperialHeight(cm: $draft.heightCm)
                    weightImperial
                } else {
                    UtilityStepper(label: "Height", value: cmBinding, step: 1, range: 120...230, unit: "cm")
                    UtilityStepper(label: "Weight", value: kgBinding, step: 1, range: 30...250, unit: "kg")
                }
            }
        }
    }

    private var weightImperial: some View {
        UtilityStepper(label: "Weight", value: lbBinding, step: 1, range: 66...550, unit: "lb")
    }

    // Bindings that present whole units while storing canonical metric.
    private var cmBinding: Binding<Int> {
        Binding(get: { Int(draft.heightCm.rounded()) }, set: { draft.heightCm = Double($0) })
    }
    private var kgBinding: Binding<Int> {
        Binding(get: { Int(draft.weightKg.rounded()) }, set: { draft.weightKg = Double($0) })
    }
    private var lbBinding: Binding<Int> {
        Binding(get: { Int((draft.weightKg * 2.2046226).rounded()) },
                set: { draft.weightKg = Double($0) / 2.2046226 })
    }
}

/// Feet + inches steppers that store centimeters.
struct ImperialHeight: View {
    @Binding var cm: Double

    private var feet: Int { Int(totalInches) / 12 }
    private var inches: Int { Int(totalInches) % 12 }
    private var totalInches: Double { (cm / 2.54).rounded() }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Eyebrow(text: "Height")
            HStack(spacing: Spacing.l) {
                UtilityStepper(label: "Feet", value: feetBinding, step: 1, range: 3...8, unit: "ft")
                UtilityStepper(label: "Inches", value: inchBinding, step: 1, range: 0...11, unit: "in")
            }
        }
    }

    private var feetBinding: Binding<Int> {
        Binding(get: { feet }, set: { setHeight(feet: $0, inches: inches) })
    }
    private var inchBinding: Binding<Int> {
        Binding(get: { inches }, set: { setHeight(feet: feet, inches: $0) })
    }
    private func setHeight(feet: Int, inches: Int) {
        cm = Double(feet * 12 + inches) * 2.54
    }
}

// MARK: - Goal

struct GoalStep: View {
    @Binding var draft: ProfileData
    let onContinue: () -> Void

    private let rates: [Double] = [0.25, 0.5, 0.75, 1.0]

    var body: some View {
        OnboardingScaffold(title: "What's your goal?", onContinue: onContinue) {
            VStack(alignment: .leading, spacing: Spacing.l) {
                ForEach(GoalDirection.allCases) { dir in
                    SelectableCard(title: dir.title, selected: draft.goal == dir) {
                        draft.goal = dir
                        if dir == .maintain { draft.weeklyRateKg = 0 }
                        else if draft.weeklyRateKg == 0 { draft.weeklyRateKg = 0.5 }
                        Haptics.select()
                    }
                }

                if draft.goal != .maintain {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Eyebrow(text: draft.goal == .lose ? "Weekly loss" : "Weekly gain")
                        SegmentedPicker(options: rates.map { ($0, rateLabel($0)) },
                                        selection: $draft.weeklyRateKg)
                    }
                    .transition(.opacity)
                }
            }
            .animation(Motion.easeOut, value: draft.goal)
        }
    }

    private func rateLabel(_ kg: Double) -> String {
        let lb = kg * 2.2046226
        return String(format: "%.1f lb", lb)
    }
}

// MARK: - Activity

struct ActivityStep: View {
    @Binding var activity: ActivityLevel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(title: "How active are you?", onContinue: onContinue) {
            VStack(spacing: Spacing.m) {
                ForEach(ActivityLevel.allCases) { level in
                    SelectableCard(title: level.title, detail: level.detail,
                                   selected: activity == level) {
                        activity = level; Haptics.select()
                    }
                }
            }
        }
    }
}

// MARK: - Macro split

struct SplitStep: View {
    @Binding var split: MacroSplit
    let onContinue: () -> Void
    @State private var preset: MacroSplit.Preset = .balanced

    var body: some View {
        OnboardingScaffold(title: "Pick your macros.",
                           subtitle: "You can fine-tune this anytime in Coach.",
                           onContinue: onContinue) {
            VStack(spacing: Spacing.m) {
                ForEach(MacroSplit.Preset.allCases.filter { $0 != .custom }) { p in
                    SelectableCard(title: p.title, detail: detail(p), selected: preset == p) {
                        preset = p
                        if let s = p.split { split = s }
                        Haptics.select()
                    }
                }
            }
        }
        .onAppear { preset = matchPreset(split) }
    }

    private func detail(_ p: MacroSplit.Preset) -> String {
        guard let s = p.split else { return "" }
        return "\(Int(s.protein*100))P   \(Int(s.carbs*100))C   \(Int(s.fat*100))F"
    }

    private func matchPreset(_ s: MacroSplit) -> MacroSplit.Preset {
        for p in MacroSplit.Preset.allCases where p.split == s { return p }
        return .balanced
    }
}

// MARK: - Review

struct ReviewStep: View {
    let draft: ProfileData
    let onContinue: () -> Void

    private var plan: MacroTargets {
        PlanCalculator.plan(draft.planProfile, draft.planGoal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Eyebrow(text: "Your daily plan")
                        Text("Here's where you'll\nstart, \(draft.name).")
                            .font(PickleFont.display(30))
                            .foregroundStyle(Palette.primary)
                    }

                    HStack {
                        Spacer()
                        VStack(spacing: Spacing.xs) {
                            Text("\(plan.kcal)")
                                .font(PickleFont.stat(56))
                                .foregroundStyle(Palette.primary)
                                .monospacedDigit()
                            Text("CALORIES PER DAY")
                                .font(PickleFont.eyebrow(11))
                                .tracking(2)
                                .foregroundStyle(Palette.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.l)

                    VStack(spacing: Spacing.m) {
                        MacroBar(label: "Protein", short: "P", value: plan.proteinG, target: plan.proteinG, tint: Palette.protein)
                        MacroBar(label: "Carbs", short: "C", value: plan.carbsG, target: plan.carbsG, tint: Palette.carbs)
                        MacroBar(label: "Fat", short: "F", value: plan.fatG, target: plan.fatG, tint: Palette.fat)
                    }

                    Text("Pickle refines this every week from what you log and how your weight trends, so it gets more accurate the longer you use it.")
                        .font(PickleFont.caption())
                        .foregroundStyle(Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
            PrimaryButton(title: "Build my plan", action: onContinue)
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.l)
        }
    }
}

// MARK: - Building loader

struct BuildingStep: View {
    let name: String
    let onFinished: () -> Void
    @State private var done = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            DotLoader(size: 56, dot: 12, done: done)
            Text(done ? "PLAN READY" : "BUILDING YOUR PLAN")
                .font(PickleFont.eyebrow(13))
                .tracking(3)
                .foregroundStyle(Palette.primary)
                .contentTransition(.opacity)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(for: .milliseconds(1900))
            withAnimation { done = true }
            try? await Task.sleep(for: .milliseconds(550))
            onFinished()
        }
    }
}
