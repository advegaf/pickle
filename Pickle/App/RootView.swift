import SwiftUI

/// Temporary root for Phase 1 — boots to the PICKLE wordmark on pure black.
/// Replaced by the onboarding gate + tab shell in later phases.
struct RootView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Wordmark()
        }
    }
}

/// Letterspaced PICKLE wordmark (Equinox-style). A real logo mark replaces this later.
struct Wordmark: View {
    var text: String = "PICKLE"
    var size: CGFloat = 22

    var body: some View {
        Text(spaced(text))
            .font(.custom("HelveticaNeue-Bold", size: size))
            .foregroundStyle(.white)
            .accessibilityLabel("Pickle")
    }

    private func spaced(_ s: String) -> String {
        s.map(String.init).joined(separator: "\u{2009}\u{2009}") // thin spaces between letters
    }
}

#Preview {
    RootView()
}
