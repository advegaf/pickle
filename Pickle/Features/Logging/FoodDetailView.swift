import SwiftUI

/// The shared destination for every logging path (search, scan, AI, custom). Choose a
/// portion + meal, preview the macros, add to the diary.
struct FoodDetailView: View {
    @EnvironmentObject private var store: PickleStore
    let candidate: FoodCandidate
    var presetMeal: MealSlot
    let onAdded: () -> Void

    /// When set, this screen edits an existing logged entry in place instead of adding a new one.
    let editingID: UUID?
    /// When set, new logs are stamped onto this moment (backfilling a viewed past day).
    let logDate: Date?

    @State private var amount: Double
    @State private var unit: ServingUnit
    @State private var meal: MealSlot
    @State private var isFavorite = false

    init(candidate: FoodCandidate, presetMeal: MealSlot = .current,
         editing: LoggedFood? = nil, logDate: Date? = nil, onAdded: @escaping () -> Void) {
        self.candidate = candidate
        self.presetMeal = presetMeal
        self.onAdded = onAdded
        self.editingID = editing?.id
        self.logDate = logDate
        if let e = editing {
            _amount = State(initialValue: e.amount)
            _unit = State(initialValue: e.unit)
            _meal = State(initialValue: e.meal)
        } else {
            let hasServing = candidate.nutrition.servingGrams != nil
            _amount = State(initialValue: hasServing ? 1 : 100)
            _unit = State(initialValue: hasServing ? .serving : .gram)
            _meal = State(initialValue: presetMeal)
        }
    }

    private var availableUnits: [ServingUnit] {
        candidate.nutrition.servingGrams != nil ? [.serving, .gram, .ounce] : [.gram, .ounce]
    }

    private var grams: Double {
        ServingConverter.grams(amount: amount, unit: unit,
                               gramsPerServing: candidate.nutrition.servingGrams) ?? amount
    }
    private var macros: MacroTargets { candidate.nutrition.macros(forGrams: grams) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                titleBlock
                kcalPreview
                portionControl
                mealPicker
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.l)
            .padding(.bottom, 120)
        }
        .background(Palette.background)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: editingID == nil ? "Add to log" : "Save changes") { add() }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
                .background(Palette.background)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFavorite.toggle()
                    store.upsertFood(from: candidate)
                    store.toggleFavorite(canonicalID: candidate.canonicalID)
                    Haptics.select()
                } label: {
                    // Fills (solid) when saved, outlines when not, so the saved state is
                    // unmistakable. SF Symbols here because the free Hugeicons pack has no solid heart.
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(isFavorite ? Palette.primary : Palette.tertiary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .onAppear { isFavorite = store.favorites().contains { $0.canonicalID == candidate.canonicalID } }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(candidate.name)
                .font(PickleFont.heading(24))
                .foregroundStyle(Palette.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let brand = candidate.brand {
                Text(brand)
                    .font(PickleFont.body(15))
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }

    private var kcalPreview: some View {
        VStack(spacing: Spacing.l) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(macros.kcal)")
                    .font(PickleFont.stat(48))
                    .foregroundStyle(Palette.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(macros.kcal)))
                Text("cal")
                    .font(PickleFont.body())
                    .foregroundStyle(Palette.tertiary)
            }
            .frame(maxWidth: .infinity)
            .animation(Motion.easeOut, value: macros.kcal)

            VStack(spacing: Spacing.m) {
                MacroBar(label: "Protein", short: "P", value: macros.proteinG, target: max(macros.proteinG, 1), tint: Palette.protein)
                MacroBar(label: "Carbs", short: "C", value: macros.carbsG, target: max(macros.carbsG, 1), tint: Palette.carbs)
                MacroBar(label: "Fat", short: "F", value: macros.fatG, target: max(macros.fatG, 1), tint: Palette.fat)
            }
        }
        .padding(Spacing.l)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private var portionControl: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Portion")
            HStack(spacing: Spacing.m) {
                stepButton(.minus) { adjust(-1) }
                Text(amountLabel)
                    .font(PickleFont.stat(26))
                    .foregroundStyle(Palette.primary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                stepButton(.add) { adjust(1) }
            }
            Menu {
                ForEach(availableUnits) { u in
                    Button(u.abbreviation) { changeUnit(u) }
                }
            } label: {
                HStack {
                    Text(unitLabel)
                        .font(PickleFont.bodyMedium(15))
                        .foregroundStyle(Palette.primary)
                    PickleIcon(.sort, size: 11)
                        .foregroundStyle(Palette.tertiary)
                    Spacer()
                    Text("\(Int(grams.rounded())) g")
                        .font(PickleFont.caption())
                        .foregroundStyle(Palette.tertiary)
                        .monospacedDigit()
                }
                .padding(Spacing.m)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            }
        }
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Add to")
            HStack(spacing: Spacing.s) {
                ForEach(MealSlot.allCases) { m in
                    let active = meal == m
                    Button {
                        meal = m; Haptics.select()
                    } label: {
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

    private var amountLabel: String {
        amount == amount.rounded() ? String(Int(amount)) : String(format: "%.1f", amount)
    }
    private var unitLabel: String {
        let plural = amount != 1
        switch unit {
        case .serving: return plural ? "servings" : "serving"
        default: return unit.abbreviation
        }
    }

    private func stepButton(_ glyph: Glyph, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PickleIcon(glyph, size: 16)
                .foregroundStyle(Palette.primary)
                .frame(width: 48, height: 48)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.pressable)
    }

    private func step(for unit: ServingUnit) -> Double {
        switch unit {
        case .serving: return 0.5
        case .gram: return 10
        case .ounce: return 1
        default: return 1
        }
    }

    private func adjust(_ direction: Double) {
        let next = amount + direction * step(for: unit)
        amount = max(next, step(for: unit))
        Haptics.select()
    }

    private func changeUnit(_ u: ServingUnit) {
        unit = u
        amount = u == .serving ? 1 : (u == .gram ? 100 : 4)
        Haptics.select()
    }

    private func add() {
        if let id = editingID {
            store.updateLog(id: id, amount: amount, unit: unit, meal: meal, macros: macros)
        } else {
            store.log(candidate, amount: amount, unit: unit, meal: meal, macros: macros,
                      at: logDate ?? Date())
        }
        Haptics.logAdded()
        onAdded()
    }
}
