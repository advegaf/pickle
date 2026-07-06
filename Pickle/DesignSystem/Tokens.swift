import SwiftUI

// MARK: - Color

/// Pickle's color system: the Glow language. Deep green-black canvas, one aqua-teal
/// accent, glass-look surfaces. Raw hex values live in `Shared/PaletteValues.swift`
/// (shared with the widget). Ratios asserted in `TokensTests`.
enum Palette {
    /// The canvas. Everything sits on this.
    static let background = Color(hex: PaletteValues.background)
    /// Warm-white primary text. TEXT intent only; use `accent` for emphasis.
    static let primary = Color(hex: PaletteValues.primary)
    /// Secondary text / metadata.
    static let secondary = Color(hex: PaletteValues.secondary)
    /// Tertiary text. Lowest token allowed to carry essential text.
    static let tertiary = Color(hex: PaletteValues.tertiary)
    /// Decorative only (gauge tracks, inactive dots). NEVER text or interactive glyphs.
    static let faint = Color(hex: PaletteValues.faint)
    /// Hairline divider, white at 10%.
    static let hairline = Color.white.opacity(0.10)
    /// The 1px top-edge highlight that sells the glass look on cards.
    static let glassEdge = Color.white.opacity(0.06)
    /// Card / control surface.
    static let surface = Color(hex: PaletteValues.surface)
    /// Slightly raised surface (pressed / selected).
    static let surfaceRaised = Color(hex: PaletteValues.surfaceRaised)
    /// Prominent (hero) card surface, one tone lighter than `surface`.
    static let surfaceElevated = Color(hex: PaletteValues.surfaceElevated)
    /// The one accent: aqua teal. Gauge fill, active tabs, selection, emphasis.
    static let accent = Color(hex: PaletteValues.accent)
    /// Soft glow shadow color derived from the accent.
    static let glow = Color(hex: PaletteValues.accent).opacity(0.5)
    /// Text and glyphs on `accent` or on white controls.
    static let onAccent = Color(hex: PaletteValues.onAccent)
    /// Success states share the accent (single-accent language).
    static let success = Color(hex: PaletteValues.accent)
    /// Over budget / destructive coral.
    static let over = Color(hex: PaletteValues.over)

    // Macro hues: one family, scannable at a glance. Protein shares the accent teal.
    static let protein = Color(hex: PaletteValues.protein)
    static let carbs = Color(hex: PaletteValues.carbs)
    static let fat = Color(hex: PaletteValues.fat)
}

// MARK: - Typography

/// SF Pro via the system font, with Dynamic Type preserved: arbitrary point sizes are
/// scaled through `UIFontMetrics` relative to a text style, matching what the old
/// `Font.custom(_:size:relativeTo:)` did. Never use raw `Font.system(size:)` in views.
enum PickleFont {
    /// Legacy face shim so older call sites (`font(.bold, 34)`) keep compiling while
    /// screens migrate. Bold maps to semibold: the Glow language has no heavier weight.
    enum Face {
        case regular, medium, bold, light

        var weight: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .bold: .semibold
            case .light: .light
            }
        }
    }

    /// Scale an arbitrary size with Dynamic Type, relative to a text style.
    static func scaled(_ size: CGFloat,
                       relativeTo style: Font.TextStyle = .body,
                       weight: Font.Weight = .regular) -> Font {
        let scaled = UIFontMetrics(forTextStyle: style.uiTextStyle).scaledValue(for: size)
        return .system(size: scaled, weight: weight)
    }

    static func font(_ face: Face, _ size: CGFloat, relativeTo: Font.TextStyle = .body) -> Font {
        scaled(size, relativeTo: relativeTo, weight: face.weight)
    }

    /// Big display headline, sentence case.
    static func display(_ size: CGFloat = 34) -> Font { scaled(size, relativeTo: .largeTitle, weight: .semibold) }
    /// Onboarding display. Sentence case in the Glow language.
    static func onboarding(_ size: CGFloat = 36) -> Font { scaled(size, relativeTo: .largeTitle, weight: .semibold) }
    /// Section heading.
    static func heading(_ size: CGFloat = 22) -> Font { scaled(size, relativeTo: .title2, weight: .semibold) }
    /// Sentence-case section label (replaces the ALL-CAPS eyebrow).
    static func label(_ size: CGFloat = 13) -> Font { scaled(size, relativeTo: .footnote, weight: .medium) }
    /// Large stat numeral. Tabular digits so updating numbers never shift layout.
    static func stat(_ size: CGFloat = 40) -> Font {
        scaled(size, relativeTo: .largeTitle, weight: .semibold).monospacedDigit()
    }
    /// Body copy.
    static func body(_ size: CGFloat = 16) -> Font { scaled(size, relativeTo: .body, weight: .regular) }
    /// Emphasised body.
    static func bodyMedium(_ size: CGFloat = 16) -> Font { scaled(size, relativeTo: .body, weight: .medium) }
    /// Small metadata.
    static func caption(_ size: CGFloat = 13) -> Font { scaled(size, relativeTo: .footnote, weight: .regular) }
    /// Button label.
    static func button(_ size: CGFloat = 16) -> Font { scaled(size, relativeTo: .body, weight: .medium) }
}

extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
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
    /// Controls and inputs.
    static let button: CGFloat = 16
    /// Cards. Concentric rule: outer = inner + padding.
    static let card: CGFloat = 24
    /// Small chips and tags.
    static let chip: CGFloat = 12
    /// Full pill (floating bar, primary CTAs, day pills).
    static let pill: CGFloat = 100
}

enum Hairline {
    static let width: CGFloat = 1
}

// MARK: - Motion

/// Emil's framework, encoded. UI animations stay under 300ms with a strong ease-out;
/// sheets get up to ~450ms. Movement is gated behind Reduce Motion at the call site.
/// One source of truth for every transition so the whole app moves with one rhythm.
enum Motion {
    /// Duration tokens (seconds).
    enum Duration {
        static let instant: Double = 0
        static let fast: Double = 0.15
        static let base: Double = 0.22
        static let slow: Double = 0.32
        static let sheet: Double = 0.45
    }

    /// Distance tokens (points) for entrance/exit travel.
    enum Distance {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    /// Blur tokens (points). Entrances blur in from a few points to sharp.
    enum Blur {
        static let entrance: CGFloat = 4
    }

    /// Scale tokens. Press dips to 0.96; entrances grow from 0.96.
    enum Scale {
        static let press: CGFloat = 0.96
        static let entranceFrom: CGFloat = 0.96
    }

    // Easing curves (Emil's strong variants).
    /// Strong ease-out for entrances and state changes. Approx cubic-bezier(0.23, 1, 0.32, 1).
    static let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: Duration.base)
    /// Strong ease-in-out for on-screen movement.
    static let easeInOut = Animation.timingCurve(0.77, 0, 0.175, 1, duration: Duration.slow)
    /// iOS-like drawer curve for sheets.
    static let drawer = Animation.timingCurve(0.32, 0.72, 0, 1, duration: Duration.sheet)
    /// Press feedback.
    static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: Duration.fast)
    /// Subtle spring for alive elements (dynamic numbers). Bounce approx 0.15.
    static let lively = Animation.spring(response: 0.4, dampingFraction: 0.82)

    /// Calm draw-in for the gauge arc, FIRST LAUNCH ONLY. Subsequent appearances sit at
    /// their value (no sweep-from-zero); day changes and new logs use `ringGrow`.
    static let ringDraw = Animation.easeOut(duration: 0.7)

    /// Gentle grow when the gauge/bars change value (a new log, a day switch).
    static let ringGrow = Animation.easeOut(duration: 0.45)

    /// The standard entrance animation (fast ease-out).
    static let entrance = easeOut

    /// Stagger delay between list items on first appearance.
    static let stagger: Double = 0.05
}

// MARK: - Entrance transition

/// A reusable entrance: opacity, a short upward translate, and a slight blur that resolves to
/// sharp. Driven by an internal appeared flag, gated by Reduce Motion (plain fade), optionally
/// staggered by index. Apply with `.pickleEntrance()`.
struct PickleEntrance: ViewModifier {
    var index: Int = 0
    var distance: CGFloat = Motion.Distance.small
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : distance))
            .blur(radius: reduceMotion ? 0 : (appeared ? 0 : Motion.Blur.entrance))
            .onAppear {
                withAnimation(reduceMotion
                              ? .easeOut(duration: Motion.Duration.base)
                              : Motion.entrance.delay(Double(index) * Motion.stagger)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// Staggered entrance using the shared motion tokens.
    func pickleEntrance(index: Int = 0, distance: CGFloat = Motion.Distance.small) -> some View {
        modifier(PickleEntrance(index: index, distance: distance))
    }
}
