import SwiftUI

// MARK: - Color

extension Color {
    /// Build a Color from a hex string like "1A1A1A" or "#1A1A1A".
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        default: // RRGGBB
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Pickle's color system. Pure-black canvas; white is the accent. Every essential-text
/// token meets WCAG 4.5:1 on `#000`. Ratios validated in `TokensTests` (Phase 3).
enum Palette {
    /// #000000 — the canvas. Everything sits on this.
    static let background = Color(hex: "000000")
    /// #FFFFFF — primary text + the one accent.
    static let primary = Color(hex: "FFFFFF")        // 21:1 on black
    /// #A3A3A3 — secondary text / metadata.
    static let secondary = Color(hex: "A3A3A3")      // ~7.0:1 on black
    /// #8A8A8A — tertiary text. Raised from #6B6B6B (which fails 4.5:1). Lowest token
    /// allowed to carry essential text.
    static let tertiary = Color(hex: "8A8A8A")       // ~5.0:1 on black
    /// #5C5C5C — decorative only (empty rings, inactive dots). NEVER essential text.
    static let faint = Color(hex: "5C5C5C")          // ~3.0:1 — decorative only
    /// Hairline divider — white at 12%.
    static let hairline = Color.white.opacity(0.12)
    /// Card / control surface on black.
    static let surface = Color(hex: "1A1A1A")
    /// Slightly raised surface (pressed / selected).
    static let surfaceRaised = Color(hex: "242424")
    /// Success ✓ — a restrained green, used sparingly.
    static let success = Color(hex: "4ADE80")        // semantic only

    // Macro tints — desaturated so color stays scarce. Used only on macro bars/labels.
    static let protein = Color(hex: "E8E3D3")  // warm bone
    static let carbs = Color(hex: "C9C2B0")    // muted clay
    static let fat = Color(hex: "AFA890")      // olive-stone
}

// MARK: - Typography

/// Helvetica Neue — ships with iOS, the heart of the Equinox look. All sizes scale with
/// Dynamic Type via `relativeTo`. Use `.pickle(...)` rather than raw `.custom`.
enum PickleFont {
    enum Face: String {
        case regular = "HelveticaNeue"
        case medium = "HelveticaNeue-Medium"
        case bold = "HelveticaNeue-Bold"
        case light = "HelveticaNeue-Light"
    }

    static func font(_ face: Face, _ size: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
        .custom(face.rawValue, size: size, relativeTo: relativeTo)
    }

    /// Big editorial headline, sentence case. ("What will you fuel today?")
    static func display(_ size: CGFloat = 34) -> Font { font(.bold, size, relativeTo: .largeTitle) }
    /// Onboarding all-caps display. (Caps handled at the call site / via .textCase.)
    static func onboarding(_ size: CGFloat = 36) -> Font { font(.bold, size, relativeTo: .largeTitle) }
    /// Section heading.
    static func heading(_ size: CGFloat = 22) -> Font { font(.bold, size, relativeTo: .title2) }
    /// Eyebrow micro-label, ALL CAPS + wide tracking applied by the `Eyebrow` view.
    static func eyebrow(_ size: CGFloat = 11) -> Font { font(.medium, size, relativeTo: .caption2) }
    /// Large stat numeral (the kcal hero, "Your Stats").
    static func stat(_ size: CGFloat = 40) -> Font { font(.bold, size, relativeTo: .largeTitle) }
    /// Body copy.
    static func body(_ size: CGFloat = 16) -> Font { font(.regular, size, relativeTo: .body) }
    /// Emphasised body.
    static func bodyMedium(_ size: CGFloat = 16) -> Font { font(.medium, size, relativeTo: .body) }
    /// Small metadata.
    static func caption(_ size: CGFloat = 13) -> Font { font(.regular, size, relativeTo: .footnote) }
    /// Button label.
    static func button(_ size: CGFloat = 16) -> Font { font(.medium, size, relativeTo: .body) }
}

// MARK: - Spacing / Shape / Hairline

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
    /// Standard screen horizontal inset.
    static let screen: CGFloat = 20
}

enum Radius {
    /// Sharp — buttons and most surfaces. Equinox is near-square.
    static let button: CGFloat = 2
    static let card: CGFloat = 4
    /// Pill (floating Log button).
    static let pill: CGFloat = 100
}

enum Hairline {
    static let width: CGFloat = 1
}

// MARK: - Motion

/// Emil's framework, encoded. UI animations stay under 300ms with a strong ease-out;
/// sheets get up to ~450ms. Movement is gated behind Reduce Motion at the call site.
enum Motion {
    /// Strong ease-out for entrances / state changes. ≈ cubic-bezier(0.23, 1, 0.32, 1).
    static let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
    /// Strong ease-in-out for on-screen movement.
    static let easeInOut = Animation.timingCurve(0.77, 0, 0.175, 1, duration: 0.32)
    /// iOS-like drawer curve for sheets.
    static let drawer = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.45)
    /// Press feedback.
    static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    /// Subtle spring for "alive" elements (ring fill, dynamic numbers). bounce ≈ 0.15.
    static let lively = Animation.spring(response: 0.4, dampingFraction: 0.82)

    /// Stagger delay between list items on first appearance.
    static let stagger: Double = 0.05
}
