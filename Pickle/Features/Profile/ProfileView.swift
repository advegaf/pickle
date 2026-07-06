import SwiftUI

/// Tapped from the Home avatar. A read-only summary of who you are and your current plan, with
/// an "Edit plan" button into the existing recalculate flow and an Apple Health shortcut.
struct ProfileView: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRecalc = false
    @State private var showHealth = false
    @AppStorage(HomeGaugeLayout.storageKey, store: UserDefaults(suiteName: AppConfig.appGroup))
    private var layoutRaw = HomeGaugeLayout.stacked.rawValue

    private var profile: ProfileData { store.profile() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    identity
                    statsCard
                    planCard
                    layoutPicker
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

    // MARK: Home layout picker

    private var layoutPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(text: "Home layout")
            HStack(spacing: Spacing.m) {
                layoutTile(.stacked)
                layoutTile(.sideBySide)
            }
        }
    }

    private func layoutTile(_ option: HomeGaugeLayout) -> some View {
        let selected = layoutRaw == option.rawValue
        return Button {
            if !selected {
                layoutRaw = option.rawValue
                Haptics.select()
            }
        } label: {
            VStack(spacing: Spacing.s) {
                LayoutSchematic(layout: option)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .padding(Spacing.m)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.chip + 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.chip + 4)
                            .strokeBorder(selected ? Palette.primary : Palette.glassEdge,
                                          lineWidth: selected ? 1.5 : 1)
                    )
                Text(option.title)
                    .font(PickleFont.caption(12))
                    .foregroundStyle(selected ? Palette.primary : Palette.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(option.title) layout")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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

/// A schematic miniature of a Home hero arrangement: a partial arc for the gauge and
/// rounded bars for the macros. Drawn with shapes so it stays crisp at tile size.
private struct LayoutSchematic: View {
    let layout: HomeGaugeLayout

    var body: some View {
        Group {
            if layout == .stacked {
                VStack(spacing: 10) {
                    miniArc(size: 46, line: 5)
                    HStack(spacing: 5) {
                        miniBar(); miniBar(); miniBar()
                    }
                }
            } else {
                // Mirrors the carded hero: the arc + lines sit inside a subtle card.
                HStack(spacing: 12) {
                    miniArc(size: 40, line: 5)
                    VStack(alignment: .leading, spacing: 7) {
                        miniLine(width: 46)
                        miniLine(width: 36)
                        miniLine(width: 42)
                    }
                }
                .padding(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
        }
    }

    private func miniArc(size: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Palette.faint, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(Palette.primary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(135))
        }
        .frame(width: size, height: size)
    }

    private func miniBar() -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Palette.surfaceRaised)
            .frame(width: 26, height: 18)
    }

    private func miniLine(width: CGFloat) -> some View {
        Capsule().fill(Palette.surfaceRaised).frame(width: width, height: 5)
    }
}
