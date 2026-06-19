import SwiftUI

/// Lists favorites or custom foods, with delete/unfavorite. The canonical management home
/// for these (the Log sheet and Home Quick Links are read-only entry points).
struct SavedFoodsList: View {
    @EnvironmentObject private var store: PickleStore
    let kind: Kind

    enum Kind { case favorites, custom
        var title: String { self == .favorites ? "Favorites" : "Custom Foods" }
        var empty: String {
            self == .favorites ? "Tap the heart on any food to keep it here."
                               : "Foods you create live here."
        }
    }

    @State private var refreshToken = 0

    private var foods: [SavedFood] {
        _ = refreshToken
        return kind == .favorites ? store.favorites() : store.customFoods()
    }

    var body: some View {
        Group {
            if foods.isEmpty {
                VStack(spacing: Spacing.m) {
                    Spacer()
                    Text(kind.title).font(PickleFont.heading(20)).foregroundStyle(Palette.primary)
                    Text(kind.empty).font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, Spacing.screen)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(foods) { food in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.name).font(PickleFont.bodyMedium(16)).foregroundStyle(Palette.primary)
                                    Text(food.candidate().displayDetail)
                                        .font(PickleFont.caption(12)).foregroundStyle(Palette.tertiary)
                                }
                                Spacer()
                                Button {
                                    if kind == .favorites { store.toggleFavorite(canonicalID: food.canonicalID) }
                                    else { store.deleteFood(canonicalID: food.canonicalID) }
                                    Haptics.select()
                                    refreshToken += 1
                                } label: {
                                    PickleIcon(kind == .favorites ? .favorite : .delete, size: 16)
                                        .foregroundStyle(Palette.tertiary)
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.pressable)
                            }
                            .frame(minHeight: 56)
                            Divider().overlay(Palette.hairline)
                        }
                    }
                    .padding(.horizontal, Spacing.screen)
                }
            }
        }
        .navigationTitle(kind.title)
    }
}

/// Export the full diary as CSV or JSON via the share sheet.
struct ExportView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var csvURL: URL?
    @State private var jsonURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Export your data")
                    .font(PickleFont.display(28)).foregroundStyle(Palette.primary)
                Text("Download everything you've logged. This file contains your full nutrition and weight history, keep it somewhere private.")
                    .font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Spacing.m) {
                if let csvURL {
                    ShareLink(item: csvURL) { exportRow("Export as CSV", "Spreadsheet-friendly") }
                }
                if let jsonURL {
                    ShareLink(item: jsonURL) { exportRow("Export as JSON", "Full structured data") }
                }
            }
            Spacer()
        }
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Export")
        .onAppear {
            let days = store.allDiaryDays()
            csvURL = ExportFile.write(days: days, format: .csv)
            jsonURL = ExportFile.write(days: days, format: .json)
        }
    }

    private func exportRow(_ title: String, _ detail: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PickleFont.bodyMedium(16)).foregroundStyle(Palette.primary)
                Text(detail).font(PickleFont.caption()).foregroundStyle(Palette.tertiary)
            }
            Spacer()
            PickleIcon(.share, size: 20).foregroundStyle(Palette.primary)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }
}
