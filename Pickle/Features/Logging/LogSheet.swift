import SwiftUI

/// The full-height logging sheet. One mode row (Search / Scan / AI / Quick); every path
/// converges on Food detail and writes to the diary, updating Home and the widget at once.
struct LogSheet: View {
    @Environment(\.dismiss) private var dismiss
    var presetMeal: MealSlot = .snack

    @State private var mode: Mode = .search
    @State private var path: [Route] = []

    enum Mode: String, CaseIterable, Identifiable {
        case search = "Search", scan = "Scan", ai = "AI", quick = "Quick"
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
                default: break
                }
                #endif
            }
        }
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
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
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
        case .search:
            SearchView(
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
                        .font(PickleFont.button(14))
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
