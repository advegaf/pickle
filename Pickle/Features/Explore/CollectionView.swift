import SwiftUI

/// A curated, recommended list of foods for an Explore collection or category. Each row opens
/// the food detail to log it. Offline and instant, drawn from the bundled CommonFoods set.
struct CollectionView: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let foods: [FoodCandidate]

    @State private var path: [FoodCandidate] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(PickleFont.body(15))
                            .foregroundStyle(Palette.tertiary)
                            .padding(.bottom, Spacing.m)
                    }

                    if foods.isEmpty {
                        Text("Nothing curated here yet. Use Search to find a food to log.")
                            .font(PickleFont.body(15))
                            .foregroundStyle(Palette.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Spacing.xl)
                    } else {
                        ForEach(foods) { food in
                            FoodRow(candidate: food) { path.append(food) }
                            if food.id != foods.last?.id { Divider().overlay(Palette.hairline) }
                        }
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Palette.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.primary)
                }
            }
            .navigationDestination(for: FoodCandidate.self) { food in
                FoodDetailView(candidate: food, presetMeal: .current, onAdded: { dismiss() })
            }
        }
        .presentationBackground(Palette.background)
    }
}
