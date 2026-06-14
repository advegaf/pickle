import SwiftUI

/// Temporary root — during Phase 2 it shows the design-system gallery for the visual
/// verification loop. Replaced by the onboarding gate + tab shell in Phase 5.
struct RootView: View {
    var body: some View {
        DesignSystemGallery()
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
