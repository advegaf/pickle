import SwiftUI

/// Tapped from the Home avatar. A read-only summary of who you are and your current plan, with
/// an "Edit plan" button into the existing recalculate flow and an Apple Health shortcut.
struct ProfileView: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRecalc = false
    @State private var showHealth = false

    private var profile: ProfileData { store.profile() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    identity
                    statsCard
                    planCard
                    actions
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Palette.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.primary)
                }
            }
        }
        .presentationBackground(Palette.background)
        .sheet(isPresented: $showRecalc) { RecalculateSheet().environmentObject(store) }
        .sheet(isPresented: $showHealth) {
            NavigationStack {
                AppleHealthView()
                    .environmentObject(store)
                    .background(Palette.background)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showHealth = false }.foregroundStyle(Palette.primary) } }
            }
            .presentationBackground(Palette.background)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ZStack {
                Circle().stroke(Palette.hairline, lineWidth: 1).frame(width: 72, height: 72)
                Text(initials).font(PickleFont.display(26)).foregroundStyle(Palette.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name.isEmpty ? "Your profile" : profile.name)
                    .font(PickleFont.display(30)).foregroundStyle(Palette.primary)
                Text(profile.goal.title).font(PickleFont.body(15)).foregroundStyle(Palette.tertiary)
            }
        }
    }

    private var statsCard: some View {
        VStack(spacing: 0) {
            row("Sex", String(describing: profile.sex).capitalized)
            divider
            row("Age", "\(profile.age)")
            divider
            row("Height", heightLabel)
            divider
            row("Weight", weightLabel)
            if profile.leanMassKg > 0 { divider; row("Lean mass", lbLabel(profile.leanMassKg)) }
            divider
            row("Activity", profile.activity.title)
        }
        .padding(Spacing.l)
        .glassCard()
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Your plan")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(profile.targets.kcal)")
                    .font(PickleFont.stat(40)).foregroundStyle(Palette.primary).monospacedDigit()
                Text("cal / day").font(PickleFont.body()).foregroundStyle(Palette.tertiary)
            }
            HStack(spacing: Spacing.m) {
                MacroChip(value: "\(profile.targets.proteinG)g", label: "Protein", tint: Palette.protein)
                MacroChip(value: "\(profile.targets.carbsG)g", label: "Carbs", tint: Palette.carbs)
                MacroChip(value: "\(profile.targets.fatG)g", label: "Fat", tint: Palette.fat)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            PrimaryButton(title: "Edit plan") { showRecalc = true }
            SecondaryButton(title: "Apple Health") { showHealth = true }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
            Spacer()
            Text(value).font(PickleFont.bodyMedium(15)).foregroundStyle(Palette.primary).monospacedDigit()
        }
        .frame(minHeight: 40)
    }

    private var divider: some View { Divider().overlay(Palette.hairline) }

    private var initials: String {
        let parts = profile.name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "P" : letters.uppercased()
    }

    private var heightLabel: String {
        let totalInches = (profile.heightCm / 2.54).rounded()
        let ft = Int(totalInches) / 12, inch = Int(totalInches) % 12
        return "\(ft)' \(inch)\""
    }
    private var weightLabel: String { lbLabel(profile.weightKg) }
    private func lbLabel(_ kg: Double) -> String { "\(Int((kg * 2.2046226).rounded())) lb" }
}
