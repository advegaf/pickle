import SwiftUI

/// The five-tab shell. Content for each tab is filled in by later phases; the bar and the
/// floating Log pill live here.
struct MainTabView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var selection = 0
    @State private var logRequest: LogRequest?
    /// Tabs are created on first visit and then kept alive (hidden via opacity), so a tab
    /// never rebuilds on return, the kcal ring never re-animates, and switching cross-fades.
    @State private var visited: Set<Int> = [0]

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.background.ignoresSafeArea()

            ZStack {
                keptTab(0) { HomeView(onLog: { logRequest = LogRequest(meal: .current) },
                                      onLogMeal: { logRequest = LogRequest(meal: $0) }) }
                keptTab(1) { ExploreView() }
                keptTab(2) { CoachView() }
                keptTab(3) { ActivityView() }
                keptTab(4) { MoreView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Motion.easeOut, value: selection)

            PickleTabBar(items: PickleTabItem.pickleTabs, selection: $selection)
        }
        .onChange(of: selection) { _, new in visited.insert(new) }
        .sheet(item: $logRequest) { request in
            LogSheet(presetMeal: request.meal)
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
    /// when selected. Keeping it alive preserves its state (and stops the ring re-animating).
    @ViewBuilder private func keptTab<V: View>(_ index: Int, @ViewBuilder _ content: () -> V) -> some View {
        if visited.contains(index) {
            content()
                .opacity(selection == index ? 1 : 0)
                .allowsHitTesting(selection == index)
        }
    }
}

/// Identifies a Log-sheet presentation, carrying which meal to preselect.
struct LogRequest: Identifiable {
    let meal: MealSlot
    var id: String { meal.rawValue }
}

