import SwiftUI

/// Create a reusable food with your own numbers. Saved to your custom foods, then it flows
/// straight into the Food detail so you can log it now.
struct CustomFoodView: View {
    @EnvironmentObject private var store: PickleStore
    var prefillName: String = ""
    let onCreated: (FoodCandidate) -> Void

    @State private var name = ""
    @State private var brand = ""
    @State private var servingGrams = 100
    @State private var kcal = 0
    @State private var protein = 0
    @State private var carbs = 0
    @State private var fat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    UnderlineField(label: "Name", text: $name)
                    UnderlineField(label: "Brand (optional)", text: $brand)
                }

                VStack(alignment: .leading, spacing: Spacing.m) {
                    Eyebrow(text: "Nutrition per serving")
                    UtilityStepper(label: "Serving size", value: $servingGrams, step: 5, range: 1...2000, unit: "g")
                    UtilityStepper(label: "Calories", value: $kcal, step: 10, range: 0...5000, unit: "cal")
                    HStack(spacing: Spacing.l) {
                        UtilityStepper(label: "Protein", value: $protein, step: 1, range: 0...500, unit: "g")
                        UtilityStepper(label: "Carbs", value: $carbs, step: 1, range: 0...500, unit: "g")
                    }
                    HStack(spacing: Spacing.l) {
                        UtilityStepper(label: "Fat", value: $fat, step: 1, range: 0...300, unit: "g")
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.l)
            .padding(.bottom, 120)
        }
        .background(Palette.background)
        .navigationTitle("Custom food")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Save & log",
                          enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty && kcal > 0) { save() }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
                .background(Palette.background)
        }
        .onAppear { if name.isEmpty { name = prefillName } }
    }

    private func save() {
        let g = Double(max(servingGrams, 1))
        let nutrition = FoodNutrition(
            kcalPer100: Double(kcal) * 100 / g,
            proteinPer100: Double(protein) * 100 / g,
            carbsPer100: Double(carbs) * 100 / g,
            fatPer100: Double(fat) * 100 / g,
            servingGrams: g)
        let saved = store.saveCustomFood(name: name, brand: brand.isEmpty ? nil : brand, nutrition: nutrition)
        Haptics.confirm()
        onCreated(saved.candidate())
    }
}
