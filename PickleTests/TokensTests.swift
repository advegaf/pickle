import XCTest
@testable import Pickle

/// WCAG contrast gates for the Glow palette. These are the guardrails that caught the
/// old #6B6B6B tertiary failing on black; every essential-text and interactive-glyph
/// token must keep clearing its floor as values get tuned.
final class TokensTests: XCTestCase {

    // MARK: WCAG math

    private func linear(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    private func luminance(_ hex: String) -> Double {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private func ratio(_ a: String, _ b: String) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    // MARK: Text on the canvas

    func testPrimaryTextOnBackground() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.primary, PaletteValues.background), 7.0)
    }

    func testSecondaryTextOnBackground() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.secondary, PaletteValues.background), 7.0)
    }

    func testTertiaryTextOnBackground() {
        // The lowest token allowed to carry essential text.
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.tertiary, PaletteValues.background), 5.0)
    }

    // MARK: Text on cards (most text sits on `surface`, not the canvas)

    func testSecondaryTextOnSurface() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.secondary, PaletteValues.surface), 4.5)
    }

    func testTertiaryTextOnSurface() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.tertiary, PaletteValues.surface), 4.5)
    }

    // MARK: Accent + macro hues as interactive/meaningful components (WCAG 1.4.11 floor is
    // 3:1; we hold them well above it so thin 4pt capsules stay legible)

    func testAccentOnBackground() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.accent, PaletteValues.background), 4.5)
    }

    func testMacroHuesOnBackground() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.protein, PaletteValues.background), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.carbs, PaletteValues.background), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.fat, PaletteValues.background), 4.5)
    }

    func testOverOnBackground() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.over, PaletteValues.background), 4.5)
    }

    // MARK: On-accent content

    func testOnAccentAgainstAccent() {
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.onAccent, PaletteValues.accent), 4.5)
    }

    func testOnAccentAgainstWhite() {
        // The raised white Log circle carries an onAccent glyph.
        XCTAssertGreaterThanOrEqual(ratio(PaletteValues.onAccent, "FFFFFF"), 7.0)
    }

    // MARK: Guardrail documentation

    func testFaintIsDecorativeOnly() {
        // `faint` intentionally fails interactive floors; this test documents that it must
        // stay below 3:1 so nobody is tempted to use it for glyphs "because it passes".
        XCTAssertLessThan(ratio(PaletteValues.faint, PaletteValues.background), 3.0)
    }
}
