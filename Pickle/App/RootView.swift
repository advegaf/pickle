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
            } else {
                #if DEBUG
                if LaunchOptions.open == "widgets" {
                    WidgetGallery(snapshot: store.currentSnapshot())
                } else {
                    gatedContent
                }
                #else
                gatedContent
                #endif
            }
        }
        .scrollIndicators(.hidden)
        // Rubber-band only where content genuinely overflows: fit-height screens and
        // every screen horizontally stop being grabbable (device verdict: the UIKit
        // appearance guards alone did not hold). Environment-inherited by all
        // descendant scroll views, including presented sheets.
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
        .task {
            applyLaunchOptions()
            store.refreshWidgetSnapshot()   // ensure the App-Group snapshot exists for the widget gallery
            onboarded = store.hasCompletedOnboarding
            try? await Task.sleep(for: .milliseconds(LaunchOptions.onboardStep != nil ? 200 : 1100))
            withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        }
        // Re-evaluate the gate when the store mutates, so "Delete all my data" (which removes the
        // profile) returns the app to onboarding.
        .onChange(of: store.revision) { _, _ in
            onboarded = store.hasCompletedOnboarding
        }
    }

    @ViewBuilder private var gatedContent: some View {
        if onboarded {
            MainTabView()
        } else {
            OnboardingFlow(onComplete: { withAnimation(Motion.easeOut) { onboarded = true } })
        }
    }

    private func applyLaunchOptions() {
        #if DEBUG
        if LaunchOptions.reset { DemoSeed.reset(store) }
        if LaunchOptions.seedDemo { DemoSeed.seed(store) }
        if ProcessInfo.processInfo.arguments.contains("--seed-empty") { DemoSeed.seedEmpty(store) }
        if ProcessInfo.processInfo.arguments.contains("--seed-over") { DemoSeed.seedOver(store) }
        #endif
    }
}

/// Black canvas. The wordmark reveals one letter at a time, left to right.
struct SplashView: View {
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            RevealWordmark(size: 24)
                .shadow(color: .white.opacity(0.35), radius: 18)
        }
    }
}

/// `P I C K L E` revealed letter by letter from left to right, each letter rising and
/// sharpening into place on a short stagger. Reduce Motion shows a plain fade.
struct RevealWordmark: View {
    var text: String = "PICKLE"
    var size: CGFloat = 24
    @State private var revealed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var letters: [Character] { Array(text) }
    private let perLetter: Double = 0.085

    var body: some View {
        HStack(spacing: size * 0.42) {
            ForEach(Array(letters.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .font(PickleFont.font(.bold, size))
                    .foregroundStyle(Palette.primary)
                    .opacity(i < revealed ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (i < revealed ? 0 : Motion.Distance.small))
                    .blur(radius: reduceMotion ? 0 : (i < revealed ? 0 : Motion.Blur.entrance))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pickle")
        .onAppear {
            if reduceMotion {
                withAnimation(.easeOut(duration: Motion.Duration.slow)) { revealed = letters.count }
                return
            }
            for i in letters.indices {
                withAnimation(Motion.entrance.delay(Double(i) * perLetter)) {
                    revealed = i + 1
                }
            }
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
