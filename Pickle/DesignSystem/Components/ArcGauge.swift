import SwiftUI

/// The Glow hero: a 270-degree calorie arc, gap centered at the bottom, teal fill with a
/// soft glow and a knob at the leading edge. Center shows consumed-of-goal with the
/// remaining count as the actionable secondary line.
///
/// Draw-in sweeps once per app launch; afterwards the arc sits at its value and only
/// eases when the value changes (a new log, a day switch), preserving the app's
/// documented no-sweep-on-appear motion decision.
struct ArcGauge: View {
    let consumed: Int
    let target: Int
    var diameter: CGFloat = 240
    var lineWidth: CGFloat = 20
    /// When false (first-run, no target yet), shows a dash instead of a number.
    var hasData: Bool = true
    /// True only when today is completely unlogged: the caption becomes an invitation.
    var isEmptyDay: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false
    @State private var breathe = false

    /// One sweep per launch, shared across instances (kept-alive tabs never re-fire it).
    @MainActor private static var didDrawThisLaunch = false

    private var remaining: Int { max(target - consumed, 0) }
    private var over: Int { max(consumed - target, 0) }
    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(consumed) / Double(target), 1)
    }
    /// The arc spans 270 degrees: trim covers 3/4 of the circle, rotated so the gap
    /// sits centered at the bottom (start 135, end 45 in screen degrees).
    private var trimEnd: CGFloat { 0.75 * fraction }
    /// The whole arc warms with progress (white-gray -> gold -> amber), red when over.
    private var tint: Color { over > 0 ? Palette.over : ArcRamp.color(fraction: fraction) }
    private var glowTint: Color { tint.opacity(0.5) }

    var body: some View {
        ZStack {
            // Track.
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Palette.faint.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Empty-day breathing glow on the track start, an invitation rather than a void.
            if hasData && isEmptyDay {
                Circle()
                    .trim(from: 0, to: 0.02)
                    .stroke(ArcRamp.color(fraction: 0).opacity(breathe ? 0.65 : 0.3),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .shadow(color: .white.opacity(0.3), radius: breathe ? 14 : 6)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                            breathe = true
                        }
                    }
            }

            // Progress stroke. Glow is a shadow on the stroke, never a live blur pass.
            Circle()
                .trim(from: 0, to: drawn ? trimEnd : 0)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: glowTint, radius: 14)
                .animation(reduceMotion ? nil : Motion.ringGrow, value: trimEnd)
                .animation(reduceMotion ? nil : Motion.easeOut, value: over > 0)

            // Knob at the leading edge of the progress.
            if hasData && fraction > 0 {
                knob
            }

            center
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            if Self.didDrawThisLaunch || reduceMotion {
                drawn = true
            } else {
                Self.didDrawThisLaunch = true
                withAnimation(Motion.ringDraw) { drawn = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories")
        .accessibilityValue(
            hasData
            ? "\(consumed) of \(target) calories consumed, \(over > 0 ? "\(over) over goal" : "\(remaining) remaining")"
            : "No target set yet"
        )
    }

    private var knob: some View {
        // A glassy lens riding the arc head. Hand-built (backdrop-free): the real
        // glassEffect plate rendered ~3x its frame here, so the lens look comes from a
        // translucent fill, a specular top highlight, and a thin rim instead.
        // Placement: offset to the stroke centerline (Circle().stroke centers ON the
        // path at diameter/2), then rotate about the gauge center - rotationEffect's
        // angle is animatable, so the lens TRAVELS ALONG THE ARC with the drawing
        // line instead of cutting a chord.
        let f = drawn ? fraction : 0
        let size = lineWidth + 10
        return Circle()
            .fill(.white.opacity(0.14))
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.10)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
            )
            .overlay(
                // Specular highlight kissing the top of the lens.
                Circle()
                    .fill(.white.opacity(0.35))
                    .frame(width: size * 0.38, height: size * 0.22)
                    .blur(radius: 2)
                    .offset(y: -size * 0.26)
            )
            .frame(width: size, height: size)
            .shadow(color: glowTint, radius: 10)
            .offset(x: diameter / 2)
            .rotationEffect(.degrees(135 + 270 * f))
            .animation(reduceMotion ? nil : Motion.ringGrow, value: f)
    }

    private var center: some View {
        VStack(spacing: 4) {
            Text(hasData ? consumed.formatted() : "-")
                .font(PickleFont.stat(44))
                .foregroundStyle(Palette.primary)
                .contentTransition(.numericText(value: Double(consumed)))
                .animation(reduceMotion ? nil : Motion.ringGrow, value: consumed)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if hasData {
                Text(over > 0 ? "of \(target.formatted()) · \(over.formatted()) over" : "of \(target.formatted()) kcal")
                    .font(PickleFont.caption())
                    .foregroundStyle(over > 0 ? Palette.over : Palette.secondary)
                    .monospacedDigit()

                if isEmptyDay {
                    Text("Log your first meal")
                        .font(PickleFont.caption(12))
                        .foregroundStyle(Palette.tertiary)
                } else if over == 0 {
                    Text("\(remaining.formatted()) left")
                        .font(PickleFont.caption(12))
                        .foregroundStyle(Palette.tertiary)
                        .monospacedDigit()
                }
            } else {
                Text("No target set yet")
                    .font(PickleFont.caption())
                    .foregroundStyle(Palette.tertiary)
            }
        }
        .padding(.horizontal, lineWidth + 16)
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: Spacing.xxl) {
            ArcGauge(consumed: 1023, target: 2000)
            ArcGauge(consumed: 2134, target: 2000, diameter: 200)
            ArcGauge(consumed: 0, target: 2000, diameter: 200, isEmptyDay: true)
            ArcGauge(consumed: 0, target: 0, diameter: 200, hasData: false)
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
}
