import Foundation
import UserNotifications
import UIKit

// MARK: - Settings (persisted, Codable)

/// Per-meal reminder configuration. Everything defaults OFF; the user opts in from the
/// bell or the one-time prompt after their third log.
struct ReminderSettings: Codable, Equatable {
    struct MealReminder: Codable, Equatable {
        var enabled: Bool
        var hour: Int
        var minute: Int
    }

    /// Keyed by `MealSlot.rawValue` (stable, Codable-friendly).
    var meals: [String: MealReminder]

    static let initial = ReminderSettings(meals: [
        MealSlot.breakfast.rawValue: .init(enabled: false, hour: 8, minute: 30),
        MealSlot.lunch.rawValue: .init(enabled: false, hour: 12, minute: 30),
        MealSlot.snack.rawValue: .init(enabled: false, hour: 15, minute: 30),
        MealSlot.dinner.rawValue: .init(enabled: false, hour: 18, minute: 30),
    ])

    func reminder(for meal: MealSlot) -> MealReminder {
        meals[meal.rawValue] ?? .init(enabled: false, hour: 12, minute: 0)
    }

    var anyEnabled: Bool {
        MealSlot.allCases.contains { reminder(for: $0).enabled }
    }
}

// MARK: - Pure schedule builder (unit-tested)

/// One computed notification request, as pure data.
struct ReminderSpec: Equatable {
    let identifier: String
    let meal: MealSlot
    let body: String
    let repeats: Bool
    let dateComponents: DateComponents
}

/// Turns settings into request specs. Pure functions, no UNUserNotificationCenter,
/// so every rule (suppression, identifiers, generic copy, missed-dot logic) is testable.
enum ReminderScheduleBuilder {
    static let idPrefix = "pickle.reminder."

    static func identifier(for meal: MealSlot, oneShot: Bool = false) -> String {
        "\(idPrefix)\(oneShot ? "once." : "")\(meal.rawValue)"
    }

    /// Every identifier this app could have pending (for clean removal).
    static var allIdentifiers: [String] {
        MealSlot.allCases.flatMap { [identifier(for: $0), identifier(for: $0, oneShot: true)] }
    }

    /// Generic copy only: food names and calorie numbers never reach the lock screen.
    static func body(for meal: MealSlot) -> String {
        "Time to log \(meal.title.lowercased())"
    }

    /// Specs for the enabled meals. A meal suppressed for `today` (it was logged, so
    /// today's fire would be a nag) becomes a one-shot for tomorrow; the next
    /// reschedule restores its repeating trigger.
    static func specs(settings: ReminderSettings,
                      suppressed: [String: String],
                      today: String) -> [ReminderSpec] {
        MealSlot.allCases.compactMap { meal in
            let r = settings.reminder(for: meal)
            guard r.enabled else { return nil }

            if suppressed[meal.rawValue] == today, let tomorrow = DayKey.shifted(today, by: 1) {
                var comps = dayComponents(tomorrow)
                comps.hour = r.hour
                comps.minute = r.minute
                return ReminderSpec(identifier: identifier(for: meal, oneShot: true),
                                    meal: meal, body: body(for: meal),
                                    repeats: false, dateComponents: comps)
            }

            var comps = DateComponents()
            comps.hour = r.hour
            comps.minute = r.minute
            return ReminderSpec(identifier: identifier(for: meal),
                                meal: meal, body: body(for: meal),
                                repeats: true, dateComponents: comps)
        }
    }

    /// Year/month/day components for a `yyyy-MM-dd` label.
    static func dayComponents(_ key: String) -> DateComponents {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        var c = DateComponents()
        if parts.count == 3 { c.year = parts[0]; c.month = parts[1]; c.day = parts[2] }
        return c
    }

    /// Which meal a notification identifier belongs to (nil for foreign identifiers).
    static func meal(fromIdentifier id: String) -> MealSlot? {
        guard id.hasPrefix(idPrefix) else { return nil }
        let raw = id.dropFirst(idPrefix.count).replacingOccurrences(of: "once.", with: "")
        return MealSlot(rawValue: raw)
    }

    /// The bell-dot count: enabled reminders whose fire time has passed today while the
    /// meal is still unlogged. Computed purely in-app; `getDeliveredNotifications` is
    /// not trustworthy once the user clears Notification Center.
    static func missedCount(settings: ReminderSettings,
                            today: DiaryDay,
                            suppressed: [String: String],
                            todayKey: String,
                            minutesNow: Int) -> Int {
        MealSlot.allCases.count { meal in
            let r = settings.reminder(for: meal)
            guard r.enabled, suppressed[meal.rawValue] != todayKey else { return false }
            return (r.hour * 60 + r.minute) <= minutesNow && today.entries(for: meal).isEmpty
        }
    }
}

// MARK: - Service

/// Owns reminder settings, notification authorization, scheduling, and the tap route.
/// All side effects live here; the schedule math lives in `ReminderScheduleBuilder`.
@MainActor
final class ReminderService: ObservableObject {
    static let shared = ReminderService()

    @Published private(set) var settings: ReminderSettings
    @Published private(set) var authStatus: UNAuthorizationStatus = .notDetermined
    /// Set when the user taps a reminder notification; MainTabView routes it to Log.
    @Published var tappedMeal: MealSlot?

    /// Meal rawValue -> the local day its reminder is suppressed for (already logged).
    private var suppressed: [String: String]
    private let defaults: UserDefaults

    private static let settingsKey = "pickle.reminders.settings"
    private static let suppressedKey = "pickle.reminders.suppressed"
    private static let promptShownKey = "pickle.reminders.promptShown"

    private init() {
        defaults = UserDefaults(suiteName: DiarySnapshotStore.appGroup) ?? .standard
        if let data = defaults.data(forKey: Self.settingsKey),
           let s = try? JSONDecoder().decode(ReminderSettings.self, from: data) {
            settings = s
        } else {
            settings = .initial
        }
        suppressed = (defaults.dictionary(forKey: Self.suppressedKey) as? [String: String]) ?? [:]
        refreshAuthStatus()
    }

    // MARK: Authorization

    func refreshAuthStatus() {
        Task { @MainActor in
            let s = await UNUserNotificationCenter.current().notificationSettings()
            let changed = s.authorizationStatus != authStatus
            authStatus = s.authorizationStatus
            // Self-heal after the user flips access in Settings.
            if changed { reschedule() }
        }
    }

    // MARK: Settings mutations

    func setEnabled(_ meal: MealSlot, enabled: Bool) {
        guard enabled else {
            update(meal) { $0.enabled = false }
            return
        }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let current = await center.notificationSettings().authorizationStatus
            switch current {
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                authStatus = granted ? .authorized : .denied
                if granted { update(meal) { $0.enabled = true } }
            case .denied:
                authStatus = .denied  // the sheet shows the Open Settings explainer
            default:
                authStatus = current
                update(meal) { $0.enabled = true }
            }
        }
    }

    func setTime(_ meal: MealSlot, hour: Int, minute: Int) {
        update(meal) { $0.hour = hour; $0.minute = minute }
    }

    private func update(_ meal: MealSlot, _ mutate: (inout ReminderSettings.MealReminder) -> Void) {
        var r = settings.reminder(for: meal)
        mutate(&r)
        settings.meals[meal.rawValue] = r
        persist()
        reschedule()
    }

    // MARK: Log suppression

    /// Called when a meal gets logged: today's remaining fire for it becomes a nag, so
    /// it is replaced by a one-shot for tomorrow.
    func noteLogged(meal: MealSlot, day: String, todayKey: String) {
        guard day == todayKey, settings.reminder(for: meal).enabled else { return }
        suppressed[meal.rawValue] = todayKey
        defaults.set(suppressed, forKey: Self.suppressedKey)
        reschedule()
        objectWillChange.send()
    }

    // MARK: Scheduling

    func reschedule(todayKey: String = DayKey.localDay(for: Date())) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ReminderScheduleBuilder.allIdentifiers)
        guard authStatus == .authorized || authStatus == .provisional else { return }

        // Stale suppressions (older than today) fall away naturally.
        suppressed = suppressed.filter { $0.value == todayKey }
        defaults.set(suppressed, forKey: Self.suppressedKey)

        for spec in ReminderScheduleBuilder.specs(settings: settings,
                                                  suppressed: suppressed,
                                                  today: todayKey) {
            let content = UNMutableNotificationContent()
            content.title = "Pickle"
            content.body = spec.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: spec.dateComponents,
                                                        repeats: spec.repeats)
            center.add(UNNotificationRequest(identifier: spec.identifier,
                                             content: content, trigger: trigger))
        }
    }

    // MARK: Bell dot

    func missedCount(today: DiaryDay, todayKey: String, now: Date = Date()) -> Int {
        let cal = Calendar.current
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return ReminderScheduleBuilder.missedCount(settings: settings, today: today,
                                                   suppressed: suppressed, todayKey: todayKey,
                                                   minutesNow: minutes)
    }

    // MARK: Tap routing

    func handleNotificationTap(identifier: String) {
        if let meal = ReminderScheduleBuilder.meal(fromIdentifier: identifier) {
            tappedMeal = meal
        }
    }

    // MARK: Opt-in prompt

    var shouldOfferPrompt: Bool {
        !defaults.bool(forKey: Self.promptShownKey) && !settings.anyEnabled && authStatus != .denied
    }

    func markPromptShown() {
        defaults.set(true, forKey: Self.promptShownKey)
        objectWillChange.send()
    }

    // MARK: Reset (delete-all-data)

    func resetAll() {
        settings = .initial
        suppressed = [:]
        defaults.removeObject(forKey: Self.settingsKey)
        defaults.removeObject(forKey: Self.suppressedKey)
        defaults.removeObject(forKey: Self.promptShownKey)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ReminderScheduleBuilder.allIdentifiers)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }
}
