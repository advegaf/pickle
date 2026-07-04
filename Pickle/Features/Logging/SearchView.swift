import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [FoodCandidate] = []
    @Published private(set) var phase: Phase = .suggestions

    enum Phase: Equatable { case suggestions, loading, results, empty }

    private var task: Task<Void, Never>?
    private let service: FoodSearching

    init(service: FoodSearching = FoodSearchService()) { self.service = service }

    /// `localMatches` and `suggestions` are supplied by the view (which has the store).
    func queryChanged(localMatches: @escaping (String) -> [FoodCandidate],
                      suggestions: @escaping () -> [FoodCandidate]) {
        task?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !q.isEmpty else {
            results = suggestions()
            phase = .suggestions
            return
        }

        // Instant local results while the network resolves.
        results = FoodRanking.rank(localMatches(q), query: q)
        phase = .loading

        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            let remote = await service.search(q)
            guard !Task.isCancelled else { return }
            let merged = FoodRanking.rank(localMatches(q) + remote, query: q)
            self.results = merged
            self.phase = merged.isEmpty ? .empty : .results
        }
    }
}

struct SearchView: View {
    @EnvironmentObject private var store: PickleStore
    @StateObject private var vm = SearchViewModel()
    @FocusState private var focused: Bool

    var initialQuery: String = ""
    let onSelect: (FoodCandidate) -> Void
    let onCreateCustom: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchField
            content
        }
        .onAppear {
            if !initialQuery.isEmpty && vm.query.isEmpty { vm.query = initialQuery }
            focused = initialQuery.isEmpty
            refresh()
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.s) {
            PickleIcon(.search, size: 16)
                .foregroundStyle(Palette.tertiary)
            TextField("Search foods", text: $vm.query)
                .font(PickleFont.body(17))
                .foregroundStyle(Palette.primary)
                .tint(Palette.primary)
                .focused($focused)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: vm.query) { _, _ in refresh() }
            if !vm.query.isEmpty {
                Button { vm.query = ""; refresh() } label: {
                    PickleIcon(.closeCircle, size: 18)
                        .foregroundStyle(Palette.tertiary)
                }
            }
        }
        .padding(Spacing.m)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.m)
    }

    @ViewBuilder private var content: some View {
        switch vm.phase {
        case .empty:
            emptyState
        case .suggestions where vm.results.isEmpty:
            suggestionsEmpty
        default:
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if vm.phase == .suggestions {
                    sectionHeader(store.recents().isEmpty ? "Common foods" : "Recent")
                }
                ForEach(vm.results) { food in
                    FoodRow(candidate: food) { onSelect(food) }
                    Divider().overlay(Palette.hairline)
                }
                if vm.phase == .loading {
                    HStack { Spacer(); DotLoader(size: 36, dot: 8); Spacer() }
                        .padding(.vertical, Spacing.l)
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Text("No results for \u{201C}\(vm.query)\u{201D}")
                .font(PickleFont.bodyMedium(17))
                .foregroundStyle(Palette.primary)
                .multilineTextAlignment(.center)
            Text("Add it as a custom food and it's yours from now on.")
                .font(PickleFont.body(14))
                .foregroundStyle(Palette.tertiary)
                .multilineTextAlignment(.center)
            SecondaryButton(title: "Create custom food") { onCreateCustom(vm.query) }
                .frame(maxWidth: 260)
            Spacer()
        }
        .padding(.horizontal, Spacing.screen)
    }

    private var suggestionsEmpty: some View {
        VStack(spacing: Spacing.m) {
            Spacer()
            Text("Search for a food to log")
                .font(PickleFont.body(15))
                .foregroundStyle(Palette.tertiary)
            Spacer()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        SectionLabel(text: title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.s)
    }

    private func refresh() {
        vm.queryChanged(localMatches: localMatches, suggestions: suggestions)
    }

    private func localMatches(_ q: String) -> [FoodCandidate] {
        let recents = store.recents().map { $0.candidate() }
        let favorites = store.favorites().map { $0.candidate() }
        let common = CommonFoods.search(q)
        let lower = q.lowercased()
        let localHits = (recents + favorites).filter { $0.name.lowercased().contains(lower) }
        return localHits + common
    }

    private func suggestions() -> [FoodCandidate] {
        let recents = store.recents(limit: 8).map { $0.candidate() }
        if !recents.isEmpty { return recents }
        // First run: a few popular common foods.
        return Array(CommonFoods.all.prefix(12))
    }
}

/// A single result row: name + brand/detail on the left, kcal on the right.
struct FoodRow: View {
    let candidate: FoodCandidate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name)
                        .font(PickleFont.bodyMedium(16))
                        .foregroundStyle(Palette.primary)
                        .lineLimit(1)
                    Text(candidate.displayDetail)
                        .font(PickleFont.caption(12))
                        .foregroundStyle(Palette.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                PickleIcon(.add, size: 15)
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 32, height: 32)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.name), \(candidate.displayDetail)")
    }
}
