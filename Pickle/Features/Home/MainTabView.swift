import SwiftUI

/// The five-tab shell. Content for each tab is filled in by later phases; the bar and the
/// floating Log pill live here.
struct MainTabView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var selection = 0
    @State private var showLog = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.background.ignoresSafeArea()

            Group {
                switch selection {
                case 0: HomeView(onLog: { showLog = true })
                case 1: PlaceholderTab(title: "Explore")
                case 2: PlaceholderTab(title: "Coach")
                case 3: PlaceholderTab(title: "Activity")
                default: PlaceholderTab(title: "More")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PickleTabBar(items: PickleTabItem.pickleTabs, selection: $selection)
        }
        .sheet(isPresented: $showLog) {
            // Real Log sheet arrives in Phase 7.
            LogPlaceholderSheet()
        }
    }
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

struct LogPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                Text("Log").font(PickleFont.display(28)).foregroundStyle(Palette.primary)
                Text("Logging flows land in Phase 7.")
                    .font(PickleFont.body()).foregroundStyle(Palette.secondary)
                SecondaryButton(title: "Close") { dismiss() }.frame(width: 160)
            }
            .padding(Spacing.screen)
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.background)
    }
}
