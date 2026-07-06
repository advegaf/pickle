import SwiftUI

/// How the Home hero arranges the gauge and macros. Chosen from the profile sheet;
/// persisted in the shared App Group defaults like the app's other settings.
enum HomeGaugeLayout: String, CaseIterable {
    /// Big centered gauge, macro cards below (the default).
    case stacked
    /// Smaller gauge on the left, three floating macro rows on the right.
    case sideBySide

    static let storageKey = "pickle.homeLayout"

    var title: String {
        switch self {
        case .stacked: return "Stacked"
        case .sideBySide: return "Side by side"
        }
    }
}
