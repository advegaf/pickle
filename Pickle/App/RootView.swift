import SwiftUI

/// App gate: shows onboarding until it's complete, then the main tab shell. A short splash
/// covers the first launch read.
struct RootView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var showSplash = true
    @State private var onboarded = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if onboarded {
                MainTabView()
            } else {
                OnboardingFlow(onComplete: { withAnimation(Motion.easeOut) { onboarded = true } })
            }
        }
        .task {
            applyLaunchOptions()
            onboarded = store.hasCompletedOnboarding
            try? await Task.sleep(for: .milliseconds(LaunchOptions.onboardStep != nil ? 200 : 1100))
            withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        }
    }

    private func applyLaunchOptions() {
        #if DEBUG
        if LaunchOptions.reset { DemoSeed.reset(store) }
        if LaunchOptions.seedDemo { DemoSeed.seed(store) }
        #endif
    }
}

/// Black canvas with the letterspaced wordmark, gently fading in.
struct SplashView: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            Wordmark(size: 24)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.96))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
    }
}

/// Letterspaced PICKLE wordmark.
struct Wordmark: View {
    var text: String = "PICKLE"
    var size: CGFloat = 22

    var body: some View {
        Text(spaced(text))
            .font(PickleFont.font(.bold, size))
            .tracking(2)
            .foregroundStyle(Palette.primary)
            .accessibilityLabel("Pickle")
    }

    private func spaced(_ s: String) -> String {
        s.map(String.init).joined(separator: "\u{2009}")
    }
}
