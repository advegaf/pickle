import SwiftUI

/// The full-height logging sheet. One mode row (Search / Scan / AI / Quick); every path
/// converges on Food detail and writes to the diary, updating Home and the widget at once.
struct LogSheet: View {
    @Environment(\.dismiss) private var dismiss
    var presetMeal: MealSlot = .current
    var prefillQuery: String = ""

    @State private var mode: Mode
    @State private var path: [Route] = []

    init(presetMeal: MealSlot = .current, prefillQuery: String = "") {
        self.presetMeal = presetMeal
        self.prefillQuery = prefillQuery
        // Open on Recents for fast re-logging; a prefilled query (from Explore) opens Search.
        _mode = State(initialValue: prefillQuery.isEmpty ? .recents : .search)
    }

    enum Mode: String, CaseIterable, Identifiable {
        case recents = "Recents", search = "Search", scan = "Scan", ai = "AI", quick = "Quick"
        var id: String { rawValue }
    }
    enum Route: Hashable {
        case detail(FoodCandidate)
        case custom(String)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: Spacing.l) {
                header
                ModeSelector(mode: $mode)
                    .padding(.horizontal, Spacing.screen)
                modeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, Spacing.m)
            .background(Palette.background)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let candidate):
                    FoodDetailView(candidate: candidate, presetMeal: presetMeal, onAdded: finish)
                case .custom(let query):
                    CustomFoodView(prefillName: query) { path.append(.detail($0)) }
                }
            }
            .onAppear {
                #if DEBUG
                switch LaunchOptions.open {
                case "detail":
                    if let banana = CommonFoods.all.first(where: { $0.name == "Banana" }) {
                        path = [.detail(banana)]
                    }
                case "ai": mode = .ai
                case "quick": mode = .quick
                default: break
                }
                #endif
            }
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.background)
    }

    private var header: some View {
        HStack {
            Text("Log")
                .font(PickleFont.heading(22))
                .foregroundStyle(Palette.primary)
            Spacer()
            Button { dismiss() } label: {
                PickleIcon(.close, size: 15)
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.screen)
    }

    @ViewBuilder private var modeContent: some View {
        switch mode {
        case .recents:
            RecentsView(onSelect: { path.append(.detail($0)) })
        case .search:
            SearchView(
                initialQuery: prefillQuery,
                onSelect: { path.append(.detail($0)) },
                onCreateCustom: { path.append(.custom($0)) }
            )
        case .scan:
            ScanView(onFound: { path.append(.detail($0)) },
                     onManual: { mode = .search })
        case .ai:
            AILogView(onConfirm: finish)
        case .quick:
            QuickAddView(presetMeal: presetMeal, onAdded: finish)
        }
    }

    private func finish() { dismiss() }
}

/// Recently logged foods, newest first, for one-tap re-logging (the fastest path to a log).
struct RecentsView: View {
    @EnvironmentObject private var store: PickleStore
    let onSelect: (FoodCandidate) -> Void

    private var recents: [FoodCandidate] { store.recents().map { $0.candidate() } }

    var body: some View {
        if recents.isEmpty {
            VStack(spacing: Spacing.s) {
                Spacer()
                Text("No recent foods yet")
                    .font(PickleFont.bodyMedium(17)).foregroundStyle(Palette.primary)
                Text("Foods you log show up here for one-tap re-logging.")
                    .font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, Spacing.screen)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recents) { food in
                        FoodRow(candidate: food) { onSelect(food) }
                        Divider().overlay(Palette.hairline)
                    }
                }
                .padding(.horizontal, Spacing.screen)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Custom segmented mode selector for the Log sheet.
struct ModeSelector: View {
    @Binding var mode: LogSheet.Mode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LogSheet.Mode.allCases) { m in
                let active = mode == m
                Button {
                    if mode != m { mode = m; Haptics.select() }
                } label: {
                    Text(m.rawValue)
                        .font(PickleFont.button(13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(active ? Palette.background : Palette.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(active ? Palette.primary : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(3)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button + 3))
    }
}
