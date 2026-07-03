import SwiftUI

/// The five-tab shell. One floating Liquid Glass bar carries the raised Log button and
/// all five tabs; it is supplied via `safeAreaInset` so every tab's content clears it
/// by construction. Log is reachable from ANY tab and always logs to today.
struct MainTabView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var selection = 0
    @State private var logRequest: LogRequest?
    /// Tabs are created on first visit and then kept alive (hidden via opacity), so a tab
    /// never rebuilds on return, the gauge never re-animates, and switching cross-fades.
    @State private var visited: Set<Int> = [0]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ZStack {
                keptTab(0) { HomeView(onLog: { logRequest = LogRequest(meal: .current) },
                                      onLogMeal: { logRequest = LogRequest(meal: $0, day: $1) }) }
                keptTab(1) { ExploreView() }
                keptTab(2) { CoachView() }
                keptTab(3) { ActivityView() }
                keptTab(4) { MoreView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Motion.easeOut, value: selection)
        }
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(items: PickleTabItem.pickleTabs, selection: $selection) {
                logRequest = LogRequest(meal: .current)
            }
            .padding(.horizontal, Spacing.screen + 4)
            .padding(.bottom, Spacing.s)
        }
        .onChange(of: selection) { _, new in visited.insert(new) }
        .sheet(item: $logRequest) { request in
            LogSheet(presetMeal: request.meal, logDay: request.day)
                .environmentObject(store)
        }
        .onOpenURL { url in
            // Widget deep link: pickle://log opens the Log sheet.
            if url.scheme == "pickle" && url.host == "log" {
                selection = 0
                logRequest = LogRequest(meal: .current)
            }
        }
        .task {
            #if DEBUG
            if let t = LaunchOptions.tab { selection = t }
            if ["log", "ai", "quick", "detail"].contains(LaunchOptions.open) {
                logRequest = LogRequest(meal: .lunch)
            }
            #endif
        }
    }

    /// A tab that materializes on first visit and then stays in the hierarchy, shown only
    /// when selected. Keeping it alive preserves its state (and stops the gauge re-animating).
    @ViewBuilder private func keptTab<V: View>(_ index: Int, @ViewBuilder _ content: () -> V) -> some View {
        if visited.contains(index) {
            content()
                .opacity(selection == index ? 1 : 0)
                .allowsHitTesting(selection == index)
        }
    }
}

/// Identifies a Log-sheet presentation, carrying which meal to preselect and, for
/// explicit backfill from a viewed past day, which day to log onto (nil = today).
struct LogRequest: Identifiable {
    let meal: MealSlot
    var day: String? = nil
    var id: String { "\(meal.rawValue)-\(day ?? "today")" }
}
