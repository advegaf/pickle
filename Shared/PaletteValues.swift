import SwiftUI

// The single source of truth for every brand color, compiled into BOTH the app and the
// widget extension. The app's `Palette` and the widget's `W` both derive from these hex
// values, so the two can never drift apart silently.
//
// The Ember story: true OLED black, a cold grey/white monochrome base, and ONE warm
// amber pop used scarcely (the gauge, the flame, today indicators). Contrast on
// `background` (asserted in TokensTests): primary 21:1, secondary 7.0:1,
// tertiary 5.2:1, accent ~9.7:1, over ~6:1. `faint` is under 3:1 and is therefore
// restricted to non-interactive decoration.
enum PaletteValues {
    /// True OLED black canvas.
    static let background = "000000"
    /// Card / control surface tint (neutral). Cards render as Liquid Glass tinted with this.
    static let surface = "161616"
    /// Pressed / selected surface.
    static let surfaceRaised = "222222"
    /// Pure white primary text. Text intent only; emphasis is `accent`.
    static let primary = "FFFFFF"
    /// Neutral secondary text.
    static let secondary = "A3A3A3"
    /// Tertiary text. Lowest token allowed to carry essential text.
    static let tertiary = "8A8A8A"
    /// Non-interactive tracks and decoration ONLY. Fails contrast for glyphs and text.
    static let faint = "3C3C3C"
    /// The one accent: ember amber. The gauge, the streak flame, today indicators.
    static let accent = "FFA24D"
    /// Text and glyphs placed on `accent` or on white controls.
    static let onAccent = "1F1206"
    /// Macro bars are monochrome: differentiation by label, not hue.
    static let protein = "FFFFFF"
    static let carbs = "FFFFFF"
    static let fat = "FFFFFF"
    /// Over-goal red. Clearly red (not orange) so it never reads as the amber accent.
    static let over = "FF5A5A"
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
