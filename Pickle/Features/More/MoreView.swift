import SwiftUI

/// More: image-row navigation to settings and management screens (the reference's More tab).
struct MoreView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var route: Route?

    enum Route: String, Identifiable {
        case goals, health, favorites, custom, export, about
        var id: String { rawValue }
    }

    private let rows: [(Route, String, Int)] = [
        (.goals, "Goals & Plan", 30),
        (.health, "Apple Health", 31),
        (.favorites, "Favorites", 32),
        (.custom, "Custom Foods", 33),
        (.export, "Export Data", 34),
        (.about, "About & Privacy", 35),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("More")
                    .font(PickleFont.display(34))
                    .foregroundStyle(Palette.primary)
                    .padding(.top, Spacing.s)

                VStack(spacing: Spacing.m) {
                    ForEach(rows, id: \.0) { row in
                        ImageRow(title: row.1, seed: row.2) { route = row.0 }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, 120)
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
            }
            .presentationBackground(Palette.background)
        }
    }

    @ViewBuilder private func destination(_ r: Route) -> some View {
        switch r {
        case .goals: RecalculateSheet().environmentObject(store)
        case .health: AppleHealthView().environmentObject(store)
        case .favorites: SavedFoodsList(kind: .favorites).environmentObject(store)
        case .custom: SavedFoodsList(kind: .custom).environmentObject(store)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Palette.primary)
                Text("Apple Health")
                    .font(PickleFont.display(28)).foregroundStyle(Palette.primary)
                Text("Pickle writes the calories and macros you log to Health, and reads your body weight to keep your adaptive targets accurate.")
                    .font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if health.isWriteAuthorized {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
                    Text("Connected").font(PickleFont.bodyMedium(16)).foregroundStyle(Palette.primary)
                }
            } else if !health.isAvailable {
                Text("Apple Health isn't available on this device.")
                    .font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
            } else {
                PrimaryButton(title: working ? "Connecting…" : "Connect Apple Health", enabled: !working) {
                    working = true
                    Task {
                        _ = await health.requestAuthorization()
                        if let kg = await health.latestWeightKg() { store.addWeight(kg: kg, fromHealthKit: true) }
                        working = false
                    }
                }
            }
        }
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// About + privacy.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Wordmark(size: 20).padding(.bottom, Spacing.s)
                Text("Pickle is a calorie and macro tracker built to feel like part of your phone — fast to log, honest about the math, and private by default.")
                    .font(PickleFont.body(16)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Eyebrow(text: "Privacy")
                Text("Your diary and health data stay on your device and sync privately through your iCloud. There's no account and no server holding your numbers.")
                    .font(PickleFont.body(15)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The one exception is AI logging: when you describe or photograph a meal, that text or image is sent to an AI service to estimate macros, then discarded. Nothing else leaves your device.")
                    .font(PickleFont.body(14)).foregroundStyle(Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Version 0.1.0")
                    .font(PickleFont.caption()).foregroundStyle(Palette.faint)
                    .padding(.top, Spacing.l)
            }
            .padding(Spacing.screen)
        }
    }
}
