import SwiftUI

// First-run coach marks. TipKit's popover tips proved impossible to make X-only (the
// framework consumes outside taps and invalidates the tip at the presentation layer -
// probe-verified), so these are custom: a small glass bubble anchored to the real UI,
// advancing ONLY when its close button is tapped. State persists in the shared App
// Group store; "Delete all my data" resets it.

/// The ordered steps of the first-run tour.
enum TipStep: Int, CaseIterable, Comparable {
    case log, gauge, week, predicted, bell

    static func < (lhs: TipStep, rhs: TipStep) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .log: return "Log anything in seconds"
        case .gauge: return "Your day at a glance"
        case .week: return "Tap any day"
        case .predicted: return "Your usual, predicted"
        case .bell: return "Gentle reminders"
        }
    }

    var message: String {
        switch self {
        case .log: return "Search, scan, describe it, or snap a photo - from any tab."
        case .gauge: return "The arc fills and shifts color as you eat - red only if you go over."
        case .week: return "Swipe back through past weeks; log onto a day you missed."
        case .predicted: return "PICKLE learns your routine - one tap logs your next meal."
        case .bell: return "Meal nudges that skip anything you already logged."
        }
    }
}

/// Drives the tour: which step is showing, advancing only on explicit dismissal.
@MainActor
final class CoachMarks: ObservableObject {
    static let stepKey = "pickle.tips.step"
    /// One shared store instance (never create per-view suites: writes through one
    /// instance are not observed by another - the layout-switch lesson).
    static let store = UserDefaults(suiteName: AppConfig.appGroup)

    /// The step currently on screen; nil when the tour is over (or not started).
    @Published private(set) var current: TipStep?

    private var began = false

    init() {
        #if DEBUG
        if LaunchOptions.hideTips {
            Self.store?.set(TipStep.allCases.count, forKey: Self.stepKey)
        } else if LaunchOptions.showTips || LaunchOptions.resetTips {
            Self.store?.removeObject(forKey: Self.stepKey)
        }
        #endif
    }

    /// Called when Home first appears post-onboarding; the tour starts (or resumes)
    /// from the persisted step.
    func begin() {
        guard !began else { return }
        began = true
        let raw = Self.store?.integer(forKey: Self.stepKey) ?? 0
        current = TipStep(rawValue: raw)
    }

    /// The X was tapped: persist progress and move to the next step (or finish).
    func dismissCurrent() {
        guard let step = current else { return }
        let next = step.rawValue + 1
        Self.store?.set(next, forKey: Self.stepKey)
        current = TipStep(rawValue: next)
    }

    /// Full reset (Delete all my data).
    static func reset() {
        store?.removeObject(forKey: stepKey)
    }
}

// MARK: - Anchoring

/// Collects the on-screen rects of tour targets.
struct CoachAnchorKey: PreferenceKey {
    static let defaultValue: [TipStep: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TipStep: Anchor<CGRect>],
                       nextValue: () -> [TipStep: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as the anchor for a tour step.
    func coachAnchor(_ step: TipStep) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [step: $0] }
    }
}

// MARK: - Bubble (TipKit popover anatomy: dark rounded rect + pointer arrow + X chip)

/// The popover's pointer triangle. `up` points toward an anchor ABOVE the bubble.
private struct PopoverArrow: Shape {
    let up: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}

/// The coach bubble, styled after the system tip popover the user preferred: flat
/// dark fill, generous radius, title + secondary message, round X chip. The X is the
/// ONLY dismissal.
struct CoachBubble: View {
    let step: TipStep
    /// True when the bubble sits below its anchor (arrow on top edge).
    var arrowOnTop: Bool
    /// Arrow center x, in the bubble's own coordinate space.
    var arrowX: CGFloat
    let onClose: () -> Void

    private let arrowSize = CGSize(width: 20, height: 10)

    var body: some View {
        VStack(spacing: 0) {
            if arrowOnTop {
                PopoverArrow(up: true)
                    .fill(Palette.surfaceRaised)
                    .frame(width: arrowSize.width, height: arrowSize.height)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: arrowX - arrowSize.width / 2)
            }
            HStack(alignment: .top, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(PickleFont.bodyMedium(17))
                        .foregroundStyle(Palette.primary)
                    Text(step.message)
                        .font(PickleFont.body(15))
                        .foregroundStyle(Palette.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: onClose) {
                    PickleIcon(.close, size: 11)
                        .foregroundStyle(Palette.tertiary)
                        .frame(width: 28, height: 28)
                        .background(Palette.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.pressable)
                .frame(minWidth: 44, minHeight: 44, alignment: .topTrailing)
                .accessibilityLabel("Dismiss tip")
            }
            .padding(.leading, Spacing.l)
            .padding(.trailing, Spacing.s)
            .padding(.vertical, 14)
            .background(Palette.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            if !arrowOnTop {
                PopoverArrow(up: false)
                    .fill(Palette.surfaceRaised)
                    .frame(width: arrowSize.width, height: arrowSize.height)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: arrowX - arrowSize.width / 2)
            }
        }
        .frame(maxWidth: 340)
        .shadow(color: .black.opacity(0.30), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
    }
}

/// Renders the current step's bubble adjacent to its anchor, arrow bridging the gap.
/// Attach ONCE at the shell level (MainTabView) so bubbles can float over any tab
/// content and the bar itself.
struct CoachMarkOverlay: ViewModifier {
    @ObservedObject var marks: CoachMarks

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            GeometryReader { geo in
                if let step = marks.current, let anchor = anchors[step] {
                    let rect = geo[anchor]
                    let bubbleAbove = rect.midY > geo.size.height * 0.55
                    let width = min(CGFloat(340), geo.size.width - 2 * Spacing.screen)
                    let x = min(max(rect.midX, Spacing.screen + width / 2),
                                geo.size.width - Spacing.screen - width / 2)
                    // Arrow x within the bubble, clamped clear of the 26pt corners.
                    let arrowX = min(max(rect.midX - (x - width / 2), 32), width - 32)
                    CoachBubble(step: step, arrowOnTop: !bubbleAbove, arrowX: arrowX) {
                        marks.dismissCurrent()
                    }
                    .frame(width: width)
                    .position(x: x,
                              y: bubbleAbove ? rect.minY - 6 - 52 : rect.maxY + 6 + 52)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(Motion.easeOut, value: marks.current)
        }
    }
}

extension View {
    func coachMarkOverlay(_ marks: CoachMarks) -> some View {
        modifier(CoachMarkOverlay(marks: marks))
    }
}
