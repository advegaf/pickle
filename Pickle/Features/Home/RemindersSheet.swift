import SwiftUI
import UserNotifications

/// Per-meal reminder settings, opened from the Home bell. Toggles are disabled with an
/// explainer + Settings link when notification access is denied; the sheet self-heals
/// when the user returns from Settings (auth is re-checked on foreground).
struct RemindersSheet: View {
    @EnvironmentObject private var reminders: ReminderService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private var denied: Bool { reminders.authStatus == .denied }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    if denied { deniedBanner }

                    VStack(spacing: 0) {
                        ForEach(MealSlot.allCases) { meal in
                            mealRow(meal)
                            if meal != MealSlot.allCases.last {
                                Divider().overlay(Palette.hairline).padding(.leading, Spacing.l)
                            }
                        }
                    }
                    .glassCard()

                    Text("Reminders use generic wording. What you eat never appears on your lock screen, and a meal you already logged skips its reminder.")
                        .font(PickleFont.caption(12))
                        .foregroundStyle(Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Spacing.xs)
                }
                .padding(Spacing.screen)
            }
            .background(Palette.background)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.background)
        .onAppear { reminders.refreshAuthStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reminders.refreshAuthStatus() }
        }
    }

    private func mealRow(_ meal: MealSlot) -> some View {
        let reminder = reminders.settings.reminder(for: meal)
        return HStack(spacing: Spacing.m) {
            Toggle(isOn: Binding(
                get: { reminder.enabled },
                set: { reminders.setEnabled(meal, enabled: $0) }
            )) {
                Text(meal.title)
                    .font(PickleFont.bodyMedium(16))
                    .foregroundStyle(denied ? Palette.tertiary : Palette.primary)
            }
            .tint(Palette.accent)
            .disabled(denied)

            if reminder.enabled {
                DatePicker("", selection: Binding(
                    get: { timeAsDate(reminder) },
                    set: { newDate in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        reminders.setTime(meal, hour: c.hour ?? 12, minute: c.minute ?? 0)
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Palette.accent)
            }
        }
        .padding(.horizontal, Spacing.l)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private var deniedBanner: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Notifications are off for Pickle")
                .font(PickleFont.bodyMedium(15))
                .foregroundStyle(Palette.primary)
            Text("Turn them on in Settings to get meal reminders.")
                .font(PickleFont.caption(12))
                .foregroundStyle(Palette.secondary)
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(PickleFont.button(14))
                    .foregroundStyle(Palette.primary)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.pressable)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20)
    }

    private func timeAsDate(_ r: ReminderSettings.MealReminder) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = r.hour
        comps.minute = r.minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}
