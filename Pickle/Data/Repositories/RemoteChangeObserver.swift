import Foundation
import CoreData

/// Listens for CloudKit-pushed store changes and routes them into the dedup + snapshot
/// pipeline. Without this, a log made on another device wouldn't merge twins or refresh
/// the widget until the app was reopened.
@MainActor
final class RemoteChangeObserver {
    private let store: PickleStore
    private var token: NSObjectProtocol?

    init(store: PickleStore) { self.store = store }

    func start() {
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak store] _ in
            Task { @MainActor in store?.handleRemoteChange() }
        }
    }

    func stop() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }
}
