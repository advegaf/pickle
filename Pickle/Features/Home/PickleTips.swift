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

// MARK: - Bubble

/// The coach bubble: title, message, and the ONLY dismissal - its X.
struct CoachBubble: View {
    let step: TipStep
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(PickleFont.bodyMedium(15))
                    .foregroundStyle(Palette.primary)
                Text(step.message)
                    .font(PickleFont.caption(13))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onClose) {
                PickleIcon(.close, size: 11)
                    .foregroundStyle(Palette.tertiary)
                    .frame(width: 28, height: 28)
                    .background(Palette.surfaceRaised)
                    .clipShape(Circle())
            }
            .buttonStyle(.pressable)
            .frame(width: 44, height: 44, alignment: .topTrailing)
            .accessibilityLabel("Dismiss tip")
        }
        .padding(.leading, Spacing.l)
        .padding(.vertical, Spacing.m)
        .padding(.trailing, Spacing.xs)
        .frame(maxWidth: 320, alignment: .leading)
        .glassCard(radius: 20, prominent: true)
        .accessibilityElement(children: .contain)
    }
}

/// Renders the current step's bubble near its anchor. Attach ONCE at the shell level
/// (MainTabView) so bubbles can float over any tab content and the bar itself.
struct CoachMarkOverlay: ViewModifier {
    @ObservedObject var marks: CoachMarks

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            GeometryReader { geo in
                if let step = marks.current, let anchor = anchors[step] {
                    let rect = geo[anchor]
                    let above = rect.midY > geo.size.height * 0.55
                    CoachBubble(step: step) { marks.dismissCurrent() }
                        .position(x: min(max(rect.midX, 170), geo.size.width - 170),
                                  y: above ? rect.minY - 64 : rect.maxY + 64)
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
