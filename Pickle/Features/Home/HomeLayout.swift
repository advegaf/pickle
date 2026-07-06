import SwiftUI

/// How the Home hero arranges the gauge and macros. Chosen from the profile sheet;
/// persisted in the shared App Group defaults like the app's other settings.
enum HomeGaugeLayout: String, CaseIterable {
    /// Big centered gauge, macro cards below (the default).
    case stacked
    /// Smaller gauge on the left, three floating macro rows on the right.
    case sideBySide

    static let storageKey = "pickle.homeLayout"

    /// The ONE store instance every @AppStorage site must share. SwiftUI ties its
    /// observation to the store object's identity: two views each creating their own
    /// `UserDefaults(suiteName:)` persist fine but never see each other's writes live
    /// (the bug where the layout only changed after an app relaunch).
    static let store = UserDefaults(suiteName: AppConfig.appGroup)

    var title: String {
        switch self {
        case .stacked: return "Stacked"
        case .sideBySide: return "Side by side"
        }
    }
}
