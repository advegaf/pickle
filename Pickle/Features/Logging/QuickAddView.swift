import SwiftUI

/// Raw-number entry for when you just know the macros. Fastest possible path.
struct QuickAddView: View {
    @EnvironmentObject private var store: PickleStore
    var presetMeal: MealSlot
    let onAdded: () -> Void

    @State private var kcal = 0
    @State private var protein = 0
    @State private var carbs = 0
    @State private var fat = 0
    @State private var meal: MealSlot

    init(presetMeal: MealSlot = .snack, onAdded: @escaping () -> Void) {
        self.presetMeal = presetMeal
        self.onAdded = onAdded
        _meal = State(initialValue: presetMeal)
    }

    private var impliedKcal: Int {
        Int((Double(protein) * 4 + Double(carbs) * 4 + Double(fat) * 9).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                UtilityStepper(label: "Calories", value: $kcal, step: 10, range: 0...5000, unit: "kcal")
                HStack(spacing: Spacing.l) {
                    UtilityStepper(label: "Protein", value: $protein, step: 1, range: 0...500, unit: "g")
                    UtilityStepper(label: "Carbs", value: $carbs, step: 1, range: 0...500, unit: "g")
                }
                HStack(spacing: Spacing.l) {
                    UtilityStepper(label: "Fat", value: $fat, step: 1, range: 0...300, unit: "g")
                    Color.clear.frame(maxWidth: .infinity)
                }

                if impliedKcal > 0 && abs(impliedKcal - kcal) > 30 {
                    Text("Macros imply ~\(impliedKcal) kcal. Tap to use.")
                        .font(PickleFont.caption())
                        .foregroundStyle(Palette.tertiary)
                        .onTapGesture { kcal = impliedKcal; Haptics.select() }
                }

                MealRowPicker(meal: $meal)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.l)
            .padding(.bottom, 120)
        }
        .background(Palette.background)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Add to log", enabled: kcal > 0 || impliedKcal > 0) { add() }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
                .background(Palette.background)
        }
    }

    private func add() {
        let finalKcal = kcal > 0 ? kcal : impliedKcal
        let macros = MacroTargets(kcal: finalKcal, proteinG: protein, carbsG: carbs, fatG: fat)
        let candidate = FoodCandidate(
            name: "Quick add", brand: nil, source: .custom,
            sourceID: "quick:\(UUID().uuidString)", barcode: nil,
            nutrition: FoodNutrition(kcalPer100: Double(finalKcal), proteinPer100: Double(protein),
                                     carbsPer100: Double(carbs), fatPer100: Double(fat), servingGrams: 100))
        store.log(candidate, amount: 1, unit: .serving, meal: meal, macros: macros)
        Haptics.logAdded()
        onAdded()
    }
}

/// Shared meal selector row used by Quick Add and Custom Food.
struct MealRowPicker: View {
    @Binding var meal: MealSlot
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Add to")
            HStack(spacing: Spacing.s) {
                ForEach(MealSlot.allCases) { m in
                    let active = meal == m
                    Button { meal = m; Haptics.select() } label: {
                        Text(m.title)
                            .font(PickleFont.button(13))
                            .foregroundStyle(active ? Palette.background : Palette.secondary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(active ? Palette.primary : Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }
}
