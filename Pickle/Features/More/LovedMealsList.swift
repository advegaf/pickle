import SwiftUI

/// The user's saved "loved meals" (combinations bundled from a meal section). Each can be
/// re-logged into the current time-of-day meal in one tap, or deleted.
struct LovedMealsList: View {
    @EnvironmentObject private var store: PickleStore
    @State private var justLogged: UUID?

    private var meals: [LovedMealDTO] { store.lovedMeals() }

    var body: some View {
        // Re-read whenever the store mutates (save / delete / relog), so the list is instant.
        let _ = store.revision
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if meals.isEmpty {
                    Text("No loved meals yet.\n\nOpen a meal on Home, then tap \u{201C}Save as a meal\u{201D} to bundle its items into one you can re-log anytime.")
                        .font(PickleFont.body(15))
                        .foregroundStyle(Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xl)
                } else {
                    ForEach(meals) { meal in
                        row(meal)
                        if meal.id != meals.last?.id { Divider().overlay(Palette.hairline) }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.l)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background)
    }

    private func row(_ meal: LovedMealDTO) -> some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name).font(PickleFont.bodyMedium(16)).foregroundStyle(Palette.primary)
                Text("\(meal.itemCount) item\(meal.itemCount == 1 ? "" : "s")   \(meal.totals.kcal) cal")
                    .font(PickleFont.caption(12)).foregroundStyle(Palette.tertiary).monospacedDigit()
            }
            Spacer()
            Button {
                store.logLovedMeal(id: meal.id, into: .current)
                Haptics.logAdded()
                withAnimation(Motion.easeOut) { justLogged = meal.id }
            } label: {
                HStack(spacing: 5) {
                    PickleIcon(justLogged == meal.id ? .check : .add, size: 13)
                    Text(justLogged == meal.id ? "Added" : "Log").font(PickleFont.button(13))
                }
                .foregroundStyle(Palette.background)
                .padding(.horizontal, Spacing.m)
                .frame(height: 34)
                .background(Palette.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Log \(meal.name)")

            Button {
                store.deleteLovedMeal(id: meal.id)
                Haptics.select()
            } label: {
                PickleIcon(.delete, size: 15)
                    .foregroundStyle(Palette.tertiary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Delete \(meal.name)")
        }
        .frame(minHeight: 56)
    }
}
