import SwiftUI
import UIKit

@main
struct PickleApp: App {
    @StateObject private var store = PickleStore.live()
    @State private var remoteObserver: RemoteChangeObserver?

    init() {
        // No system scroll bars anywhere. The clean Apple look; SwiftUI ScrollViews are
        // backed by UIScrollView, so this hides the indicator app wide in one place.
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
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
                }
        }
    }
}
