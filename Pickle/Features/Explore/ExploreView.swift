import SwiftUI

/// Explore: curated recipes you can log in one tap, plus category browsing.
struct ExploreView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var selection: CollectionSelection?
    @State private var recipe: Recipe?

    private let columns = [GridItem(.flexible(), spacing: Spacing.m),
                           GridItem(.flexible(), spacing: Spacing.m)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Explore")
                    .font(PickleFont.display(34))
                    .foregroundStyle(Palette.primary)
                    .padding(.top, Spacing.s)

                recipes.pickleEntrance(index: 1)
                categories.pickleEntrance(index: 2)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, 120)
        }
        .background(Palette.background)
        .sheet(item: $recipe) { r in
            RecipeDetailView(recipe: r).environmentObject(store)
        }
        .sheet(item: $selection) { sel in
            CollectionView(title: sel.title, subtitle: sel.subtitle, foods: sel.foods)
                .environmentObject(store)
        }
        .onAppear {
            #if DEBUG
            if LaunchOptions.open == "recipe", recipe == nil { recipe = Recipe.all.first }
            #endif
        }
    }

    private var recipes: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Recipes")
            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(Recipe.all) { r in
                    RecipeCard(recipe: r) { recipe = r; Haptics.select() }
                }
            }
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Browse by category")
            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(FoodCategory.allCases) { cat in
                    CategoryButton(title: cat.rawValue) {
                        selection = CollectionSelection(
                            id: "cat-\(cat.id)", title: cat.rawValue,
                            subtitle: "Recommended \(cat.rawValue.lowercased())",
                            foods: CommonFoods.recommended(forCategory: cat))
                        Haptics.select()
                    }
                }
            }
        }
    }
}

/// A tapped category, resolved to its curated foods for the CollectionView sheet.
struct CollectionSelection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let foods: [FoodCandidate]
}

/// Clean (photo-free) recipe tile: name + totals, no separators.
struct RecipeCard: View {
    let recipe: Recipe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(recipe.name)
                    .font(PickleFont.heading(18))
                    .foregroundStyle(Palette.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.s)
                HStack(spacing: 12) {
                    Text("\(recipe.totals.kcal) cal")
                        .foregroundStyle(Palette.secondary)
                    Text("\(recipe.totals.proteinG)g protein")
                        .foregroundStyle(Palette.tertiary)
                }
                .font(PickleFont.caption(12))
                .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(Spacing.l)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name), \(recipe.totals.kcal) calories, \(recipe.totals.proteinG) grams protein")
    }
}

/// Recipe detail: ingredients + totals, with a one-tap "log the whole thing".
struct RecipeDetailView: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var logged = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(recipe.name)
                            .font(PickleFont.display(28))
                            .foregroundStyle(Palette.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.m) {
                            Text("\(recipe.totals.kcal) cal")
                                .font(PickleFont.bodyMedium(15)).foregroundStyle(Palette.secondary).monospacedDigit()
                            MacroLine(macros: recipe.totals)
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Eyebrow(text: "Ingredients")
                        VStack(spacing: 0) {
                            ForEach(recipe.items) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(PickleFont.bodyMedium(16)).foregroundStyle(Palette.primary)
                                        Text("\(Int(item.grams)) g   \(item.macros.kcal) cal")
                                            .font(PickleFont.caption(12)).foregroundStyle(Palette.tertiary).monospacedDigit()
                                    }
                                    Spacer()
                                    MacroLine(macros: item.macros)
                                }
                                .frame(minHeight: 52)
                                if item.id != recipe.items.last?.id { Divider().overlay(Palette.hairline) }
                            }
                        }
                        .padding(Spacing.l)
                        .background(Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.primary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: logged ? "Added to today" : "Log recipe", enabled: !logged) {
                    for item in recipe.items {
                        _ = store.log(item.candidate, amount: 1, unit: .serving, meal: .current, macros: item.macros)
                    }
                    Haptics.logAdded()
                    logged = true
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
                .background(Palette.background)
            }
        }
        .presentationBackground(Palette.background)
    }
}
