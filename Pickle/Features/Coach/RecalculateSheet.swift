import SwiftUI

/// Adjust goal, rate, activity, and macro split, then recompute the plan. Reuses the same
/// selection components as onboarding.
struct RecalculateSheet: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ProfileData()
    @State private var preset: MacroSplit.Preset = .balanced
    private let rates: [Double] = [0.25, 0.5, 0.75, 1.0]

    private var newPlan: MacroTargets {
        PlanCalculator.plan(draft.planProfile, draft.planGoal)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    projected

                    section("Goal") {
                        ForEach(GoalDirection.allCases) { dir in
                            SelectableCard(title: dir.title, selected: draft.goal == dir) {
                                draft.goal = dir
                                if dir == .maintain { draft.weeklyRateKg = 0 }
                                else if draft.weeklyRateKg == 0 { draft.weeklyRateKg = 0.5 }
                                Haptics.select()
                            }
                        }
                        if draft.goal != .maintain {
                            SegmentedPicker(options: rates.map { ($0, rateLabel($0)) }, selection: $draft.weeklyRateKg)
                        }
                    }

                    section("Activity") {
                        ForEach(ActivityLevel.allCases) { level in
                            SelectableCard(title: level.title, detail: level.detail,
                                           selected: draft.activity == level) {
                                draft.activity = level; Haptics.select()
                            }
                        }
                    }

                    section("Macros") {
                        ForEach(MacroSplit.Preset.allCases.filter { $0 != .custom }) { p in
                            SelectableCard(title: p.title, detail: presetDetail(p), selected: preset == p) {
                                preset = p
                                if let s = p.split { draft.split = s }
                                Haptics.select()
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.l)
                .padding(.bottom, 120)
            }
            .background(Palette.background)
            .navigationTitle("Recalculate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Palette.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Save new plan") {
                    store.updateProfile(draft)
                    store.recalculatePlan()
                    Haptics.confirm()
                    dismiss()
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
                .background(Palette.background)
            }
        }
        .presentationBackground(Palette.background)
        .onAppear {
            draft = store.profile()
            preset = matchPreset(draft.split)
        }
    }

    private var projected: some View {
        VStack(spacing: Spacing.xs) {
            Text("\(newPlan.kcal)")
                .font(PickleFont.stat(48)).foregroundStyle(Palette.primary).monospacedDigit()
                .contentTransition(.numericText(value: Double(newPlan.kcal)))
                .animation(Motion.easeOut, value: newPlan.kcal)
            Text("PROJECTED DAILY CALORIES")
                .font(PickleFont.eyebrow(11)).tracking(2).foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.l)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: title)
            content()
        }
    }

    private func rateLabel(_ kg: Double) -> String { String(format: "%.1f lb", kg * 2.2046226) }
    private func presetDetail(_ p: MacroSplit.Preset) -> String {
        guard let s = p.split else { return "" }
        return "\(Int(s.protein*100))P · \(Int(s.carbs*100))C · \(Int(s.fat*100))F"
    }
    private func matchPreset(_ s: MacroSplit) -> MacroSplit.Preset {
        for p in MacroSplit.Preset.allCases where p.split == s { return p }
        return .custom
    }
}
