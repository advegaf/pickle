import SwiftUI

// The single source of truth for every brand color, compiled into BOTH the app and the
// widget extension. The app's `Palette` and the widget's `W` both derive from these hex
// values, so the two can never drift apart silently.
//
// Contrast ratios on `background` (asserted in TokensTests): primary 17.6:1,
// secondary 7.8:1, tertiary 6.1:1, accent 12.0:1, carbs 9.3:1, fat 12.1:1, over 6.9:1.
// `faint` is 1.9:1 and is therefore restricted to non-interactive decoration.
enum PaletteValues {
    /// Deep green-black canvas.
    static let background = "0B100F"
    /// Card / control surface. Separation comes from the glass edge + shadow, not the fill.
    static let surface = "151E1C"
    /// Pressed / selected surface.
    static let surfaceRaised = "1C2725"
    /// Warm-white primary text. Text intent only; emphasis is `accent`.
    static let primary = "F2F6F5"
    /// Teal-gray secondary text.
    static let secondary = "9BA8A4"
    /// Tertiary text. Lowest token allowed to carry essential text.
    static let tertiary = "8A948F"
    /// Non-interactive tracks and decoration ONLY. Fails contrast for glyphs and text.
    static let faint = "3A4441"
    /// The one accent: aqua teal. Gauge, active states, primary emphasis.
    static let accent = "4DE3C8"
    /// Text and glyphs placed on `accent` or on white controls.
    static let onAccent = "06211C"
    /// Macro hues, one family, same luminance band. Protein shares the accent teal.
    static let protein = "4DE3C8"
    static let carbs = "4DC2E3"
    static let fat = "72E3A0"
    /// Over-goal coral. Also destructive actions and the bell dot.
    static let over = "FF6B66"
}

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
