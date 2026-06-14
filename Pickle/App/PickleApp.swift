import SwiftUI

@main
struct PickleApp: App {
    @StateObject private var store = PickleStore.live()
    @State private var remoteObserver: RemoteChangeObserver?

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
                    store.refreshWidgetSnapshot()
                }
        }
    }
}
