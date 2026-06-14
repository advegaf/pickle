import SwiftUI

/// The five-tab shell. Content for each tab is filled in by later phases; the bar and the
/// floating Log pill live here.
struct MainTabView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var selection = 0
    @State private var logRequest: LogRequest?

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.background.ignoresSafeArea()

            Group {
                switch selection {
                case 0: HomeView(onLog: { logRequest = LogRequest(meal: .snack) },
                                 onLogMeal: { logRequest = LogRequest(meal: $0) })
                case 1: ExploreView()
                case 2: CoachView()
                case 3: ActivityView()
                default: PlaceholderTab(title: "More")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PickleTabBar(items: PickleTabItem.pickleTabs, selection: $selection)
        }
        .sheet(item: $logRequest) { request in
            LogSheet(presetMeal: request.meal)
                .environmentObject(store)
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
}

/// Identifies a Log-sheet presentation, carrying which meal to preselect.
struct LogRequest: Identifiable {
    let meal: MealSlot
    var id: String { meal.rawValue }
}

/// Temporary tab body used until each feature phase lands.
struct PlaceholderTab: View {
    let title: String
    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(PickleFont.display(34))
                .foregroundStyle(Palette.primary)
            Text("Coming together")
                .font(PickleFont.caption())
                .foregroundStyle(Palette.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

