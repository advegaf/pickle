import WidgetKit

/// Thin wrapper so the app can ask the widget to refresh. `reloadAllTimelines()` is
/// best-effort and budgeted by the system — the widget also self-zeroes at midnight, so a
/// missed reload never strands stale data.
enum WidgetReloader {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
