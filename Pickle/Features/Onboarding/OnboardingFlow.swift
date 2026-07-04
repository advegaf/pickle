import SwiftUI

/// The onboarding coordinator. Collects a `ProfileData` draft across light, one-thing-per-
/// screen steps, computes the plan, then writes it through the store. No accounts, this is
/// local profile setup wearing the Equinox onboarding's clothes.
struct OnboardingFlow: View {
    @EnvironmentObject private var store: PickleStore
    let onComplete: () -> Void

    @State private var step = 0
    @State private var draft = ProfileData()
    @State private var heightImperial = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func applyStartStep() {
        #if DEBUG
        if let s = LaunchOptions.onboardStep { step = s }
        #endif
    }

    // Steps that show the slim progress bar + back affordance (the data-collection middle).
    private let firstFormStep = 3
    private let lastFormStep = 8
    private let buildingStep = 9

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if step >= firstFormStep && step <= lastFormStep {
                    topBar
                }

                content
                    .id(step)
                    .transition(transition)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(reduceMotion ? .none : Motion.easeInOut, value: step)
        .onAppear(perform: applyStartStep)
    }

    private var topBar: some View {
        HStack(spacing: Spacing.m) {
            Button { back() } label: {
                PickleIcon(.chevronLeft, size: 17)
                    .foregroundStyle(Palette.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.pressable)

            ProgressLine(progress: progressFraction)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.s)
    }

    private var progressFraction: Double {
        let total = Double(lastFormStep - firstFormStep + 1)
        return Double(step - firstFormStep + 1) / total
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: HeroStep { advance() }
        case 1: PrivacyStep { advance() }
        case 2: HealthConnectStep(draft: $draft) { advance() }
        case 3: NameStep(name: $draft.name) { advance() }
        case 4: BodyStatsStep(draft: $draft, imperial: $heightImperial) { advance() }
        case 5: GoalStep(draft: $draft) { advance() }
        case 6: ActivityStep(activity: $draft.activity) { advance() }
        case 7: SplitStep(split: $draft.split) { advance() }
        case 8: ReviewStep(draft: draft) { advance() }
        default: BuildingStep(name: draft.name, onFinished: finish)
        }
    }

    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        Haptics.select()
        step += 1
        if step == buildingStep {
            // Persist the plan as we enter the building loader.
            store.completeOnboarding(draft)
        }
    }

    private func back() {
        guard step > 0 else { return }
        Haptics.select()
        step -= 1
    }

    private func finish() { onComplete() }
}

/// Slim progress line (the reference's bottom progress bar, repurposed at the top).
struct ProgressLine: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule().fill(Palette.accent)
                    .frame(width: max(geo.size.width * min(max(progress, 0), 1), 2))
                    .animation(Motion.easeOut, value: progress)
            }
        }
        .frame(height: 2)
    }
}
