import SwiftUI
import UIKit
import TipKit

/// More: image-row navigation to settings and management screens (the reference's More tab).
struct MoreView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var route: Route?

    /// Single source of truth per row (an Identifiable enum), so the grouped list binds each row's
    /// tap to its own destination.
    enum Route: String, CaseIterable, Identifiable {
        case goals, health, favorites, custom, loved, export, about
        var id: String { rawValue }

        var title: String {
            switch self {
            case .goals: return "Goals & Plan"
            case .health: return "Apple Health"
            case .favorites: return "Favorites"
            case .custom: return "Custom Foods"
            case .loved: return "Loved Meals"
            case .export: return "Export Data"
            case .about: return "About & Privacy"
            }
        }
        var icon: Glyph {
            switch self {
            case .goals: return .goal       // target, not the Coach-tab analytics glyph
            case .health: return .pulse     // ECG line, not a heart (Favorites owns the heart)
            case .favorites: return .favorite
            case .custom: return .edit
            case .loved: return .bookmark   // saved-meal bookmark, not the Explore-tab grid
            case .export: return .share
            case .about: return .shield
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("More")
                    .font(PickleFont.display(34))
                    .foregroundStyle(Palette.primary)
                    .padding(.top, Spacing.s)

                GroupedListCard {
                    ForEach(Route.allCases) { r in
                        ListRow(icon: r.icon, title: r.title) { route = r }
                            .accessibilityIdentifier("more-row-\(r.rawValue)")
                        if r != Route.allCases.last { ListRowDivider() }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.l)
        }
        .background(Palette.background)
        .sheet(item: $route) { r in
            NavigationStack {
                destination(r)
                    .background(Palette.background)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { route = nil }.foregroundStyle(Palette.primary)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        // Invisible, queryable marker so a UI test can assert which destination
                        // actually presented for a tapped row (the real row-tap -> route check).
                        Color.clear.frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityIdentifier("more-dest-\(r.rawValue)")
                    }
            }
            .scrollIndicators(.hidden)
            .presentationBackground(Palette.background)
        }
        .onAppear {
            #if DEBUG
            // `--open more-<route>` auto-presents a destination for the screenshot loop.
            if let open = LaunchOptions.open, open.hasPrefix("more-"),
               let r = Route(rawValue: String(open.dropFirst("more-".count))) {
                route = r
            } else if LaunchOptions.open == "loved-pick" {
                route = .loved
            }
            #endif
        }
    }

    @ViewBuilder private func destination(_ r: Route) -> some View {
        switch r {
        case .goals: RecalculateSheet().environmentObject(store)
        case .health: AppleHealthView().environmentObject(store)
        case .favorites: SavedFoodsList(kind: .favorites).environmentObject(store)
        case .custom: SavedFoodsList(kind: .custom).environmentObject(store)
        case .loved: LovedMealsList().environmentObject(store)
        case .export: ExportView().environmentObject(store)
        case .about: AboutView()
        }
    }
}

/// Apple Health connect + status.
struct AppleHealthView: View {
    @EnvironmentObject private var store: PickleStore
    @StateObject private var health = HealthKitService.shared
    @State private var working = false

    @State private var bodyProfile: BodyProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                PickleIcon(.health, size: 36)
                    .foregroundStyle(Palette.primary)
                Text("Apple Health")
                    .font(PickleFont.display(28)).foregroundStyle(Palette.primary)
                Text("Pickle writes the calories and macros you log to Health, and reads your body weight to keep your adaptive targets accurate.")
                    .font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if health.hasConnected { connectedState }

            Spacer()

            if !health.hasConnected {
                if !health.isAvailable {
                    Text("Apple Health isn't available on this device.")
                        .font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
                } else {
                    PrimaryButton(title: working ? "Connecting…" : "Connect Apple Health", enabled: !working) {
                        working = true
                        Task {
                            _ = await health.requestAuthorization()
                            let bp = await health.fetchBodyProfile()
                            if let kg = bp.weightKg { store.addWeight(kg: kg, fromHealthKit: true) }
                            bodyProfile = bp
                            working = false
                        }
                    }
                }
            }
        }
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            health.refreshAuthorization()
            if health.hasConnected, bodyProfile == nil {
                bodyProfile = await health.fetchBodyProfile()
            }
        }
    }

    /// Connected confirmation plus the live data we read back from Health (degrades to just the
    /// confirmation when reads come back empty, e.g. on the simulator or with read denied).
    @ViewBuilder private var connectedState: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(spacing: Spacing.s) {
                PickleIcon(.checkCircle, size: 18).foregroundStyle(Palette.success)
                Text("Connected").font(PickleFont.bodyMedium(16)).foregroundStyle(Palette.primary)
            }

            let rows = syncedRows
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        HStack {
                            Text(r.0).font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
                            Spacer()
                            Text(r.1).font(PickleFont.bodyMedium(15)).foregroundStyle(Palette.primary).monospacedDigit()
                        }
                        .frame(minHeight: 40)
                        if i < rows.count - 1 { Divider().overlay(Palette.hairline) }
                    }
                }
                .padding(Spacing.l)
                .glassCard()
            }

            TextLink(title: "Manage in the Settings app") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var syncedRows: [(String, String)] {
        guard let bp = bodyProfile else { return [] }
        var r: [(String, String)] = []
        if let w = bp.weightKg { r.append(("Weight", String(format: "%.0f lb", w * 2.2046226))) }
        if let l = bp.leanMassKg { r.append(("Lean mass", String(format: "%.0f lb", l * 2.2046226))) }
        if let s = bp.avgDailySteps { r.append(("Daily steps", "\(Int(s))")) }
        if let e = bp.avgDailyActiveEnergy { r.append(("Active energy", "\(Int(e)) cal")) }
        return r
    }
}

/// About + privacy.
struct AboutView: View {
    @EnvironmentObject private var store: PickleStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Wordmark(size: 20).padding(.bottom, Spacing.s)
                Text("Pickle is a calorie and macro tracker built to feel like part of your phone, fast to log, honest about the math, and private by default.")
                    .font(PickleFont.body(16)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SectionLabel(text: "Privacy")
                Text("Your diary and health data stay on your device and sync privately through your iCloud. There's no account and no server holding your numbers.")
                    .font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The one exception is AI logging: when you describe or photograph a meal, that text or image is sent to an AI service to estimate macros, then discarded. Nothing else leaves your device. These estimates are approximate and not medical or dietary advice.")
                    .font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                SectionLabel(text: "Your data").padding(.top, Spacing.s)
                Button { confirmDelete = true } label: {
                    HStack(spacing: Spacing.s) {
                        PickleIcon(.delete, size: 15)
                        Text("Delete all my data")
                    }
                    .font(PickleFont.button(14))
                    .foregroundStyle(Palette.over)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(Capsule()
                        .stroke(Palette.over.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.pressable)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Version 0.1.0")
                    Text("Icons by Hugeicons")
                    #if DEBUG
                    // The north-star metric, visible where only builders look.
                    if let median = LogMetric.median {
                        Text("Median seconds-to-log: \(String(format: "%.1f", median))s over \(LogMetric.sampleCount) logs")
                            .monospacedDigit()
                    }
                    #endif
                }
                .font(PickleFont.caption()).foregroundStyle(Palette.tertiary)
                .padding(.top, Spacing.l)
            }
            .padding(Spacing.screen)
        }
        .alert("Delete all your data?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) {
                store.deleteAllData()
                ReminderService.shared.resetAll()
                LogMetric.reset()
                try? Tips.resetDatastore()
                Haptics.confirm()
                dismiss()
            }
        } message: {
            Text("This permanently deletes your profile, diary, weights, and saved foods on this device. This can't be undone.")
        }
    }
}
