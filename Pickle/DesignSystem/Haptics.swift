import UIKit

/// One semantic haptic surface for the whole app. Call sites use intent
/// (`Haptics.logAdded()`), never raw generators, so the feel stays consistent and tuned.
/// Per Emil: purposeful, never on scroll, never on high-frequency keyboard-style actions.
@MainActor
enum Haptics {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Call when a screen that will trigger haptics appears, to warm the engine.
    static func prepare() {
        impactLight.prepare()
        selection.prepare()
    }

    /// A food was added to the diary.
    static func logAdded() { impactLight.impactOccurred() }

    /// A deliberate, slightly heavier confirmation (custom food saved, plan built).
    static func confirm() { impactMedium.impactOccurred() }

    /// The day's goal was met, or a milestone earned — the rare celebratory moment.
    static func celebrate() { notification.notificationOccurred(.success) }

    /// Something failed in a way the user should feel (barcode not found, AI error).
    static func warn() { notification.notificationOccurred(.warning) }

    /// Picker / segmented / tab selection change.
    static func select() { selection.selectionChanged() }
}
