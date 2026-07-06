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
    /// Prominent (hero) card surface: one step closer to the light than `surface`.
    static let surfaceElevated = "1C1C1C"
    /// Pure white primary text. Text intent only; emphasis is `accent`.
    static let primary = "FFFFFF"
    /// Neutral secondary text.
    static let secondary = "A3A3A3"
    /// Tertiary text. Lowest token allowed to carry essential text.
    static let tertiary = "8A8A8A"
    /// Non-interactive tracks and decoration ONLY. Fails contrast for glyphs and text.
    static let faint = "3C3C3C"
    /// The accent equals the gauge ramp's goal color (Whoop-orange): the streak flame
    /// and goal-met calendar days share it so "goal" reads as one color everywhere.
    static let accent = "FF6F13"
    /// Text and glyphs placed on `accent` or on white controls.
    static let onAccent = "1F1206"
    /// Macro bars are monochrome: differentiation by label, not hue.
    static let protein = "FFFFFF"
    static let carbs = "FFFFFF"
    static let fat = "FFFFFF"
    /// Over-goal: Whoop red. Reserved for exceeding the goal + destructive actions.
    static let over = "FF0026"
}

/// The gauge's progressive color, Whoop-graded: white-ish at an empty day, through
/// Whoop green and yellow, landing on orange AT the goal. Red is deliberately NOT in
/// the ramp - hitting the goal is success; over-goal callers switch to
/// `PaletteValues.over` (Whoop red) themselves. Pure math, shared with the widgets.
enum ArcRamp {
    /// Sorted (fraction, RGB 0-255) stops. Green/yellow are Whoop's exact colors;
    /// the goal orange is the exact midpoint of Whoop yellow -> Whoop red.
    static let stops: [(fraction: Double, rgb: (r: Double, g: Double, b: Double))] = [
        (0.0, (232, 232, 232)),  // #E8E8E8 white-ish
        (0.30, (22, 236, 6)),    // #16EC06 Whoop green
        (0.60, (255, 222, 0)),   // #FFDE00 Whoop yellow
        (1.0, (255, 111, 19)),   // #FF6F13 Whoop yellow->red midpoint orange
    ]

    /// Piecewise-linear RGB interpolation between stops; clamps outside 0...1.
    static func rgb(fraction: Double) -> (r: Double, g: Double, b: Double) {
        let f = min(max(fraction, 0), 1)
        guard let upperIndex = stops.firstIndex(where: { $0.fraction >= f }) else {
            return stops[stops.count - 1].rgb
        }
        if upperIndex == 0 { return stops[0].rgb }
        let lower = stops[upperIndex - 1]
        let upper = stops[upperIndex]
        let t = (f - lower.fraction) / (upper.fraction - lower.fraction)
        return (lower.rgb.r + (upper.rgb.r - lower.rgb.r) * t,
                lower.rgb.g + (upper.rgb.g - lower.rgb.g) * t,
                lower.rgb.b + (upper.rgb.b - lower.rgb.b) * t)
    }

    static func color(fraction: Double) -> Color {
        let c = rgb(fraction: fraction)
        return Color(.sRGB, red: c.r / 255, green: c.g / 255, blue: c.b / 255, opacity: 1)
    }
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
