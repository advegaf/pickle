import SwiftUI
import UIKit
import UserNotifications
import TipKit

/// Hosts the notification-center delegate. Local-notification taps NEVER reach
/// `onOpenURL`; they arrive here and are routed through ReminderService.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        await MainActor.run {
            ReminderService.shared.handleNotificationTap(identifier: identifier)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct PickleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PickleStore.live()
    @StateObject private var reminders = ReminderService.shared
    @State private var remoteObserver: RemoteChangeObserver?

    init() {
        // No system scroll bars anywhere. The clean Apple look; SwiftUI ScrollViews are
        // backed by UIScrollView, so this hides the indicator app wide in one place.
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        // Vertical screens must never wander sideways: no horizontal rubber-band, and
        // drags lock to the dominant axis so content can't drift diagonally.
        UIScrollView.appearance().alwaysBounceHorizontal = false
        UIScrollView.appearance().isDirectionalLockEnabled = true
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(reminders)
                .preferredColorScheme(.dark)
                .task {
                    // Start listening for CloudKit-pushed changes (merge twins, refresh widget).
                    if remoteObserver == nil {
                        let observer = RemoteChangeObserver(store: store)
                        observer.start()
                        remoteObserver = observer
                    }
                    Haptics.prepare()
                    HealthKitService.shared.refreshAuthorization()
                    store.refreshWidgetSnapshot()
                    reminders.reschedule()
                    #if DEBUG
                    if LaunchOptions.showTips {
                        try? Tips.resetDatastore()
                        Tips.showAllTipsForTesting()
                    }
                    if LaunchOptions.hideTips {
                        Tips.hideAllTipsForTesting()
                    }
                    #endif
                    try? Tips.configure()
                }
        }
    }
}
