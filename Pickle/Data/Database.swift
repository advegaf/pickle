import Foundation
import SwiftData

/// Builds the SwiftData stack. Models are CloudKit-compatible; sync is gated behind
/// `AppConfig.useCloudKit` so the simulator/CI run on a stable local store (the tested
/// path) and a device with the iCloud entitlement flips sync on with one flag.
enum Database {
    static let schema = Schema([
        UserProfile.self,
        FoodItemEntry.self,
        LogEntry.self,
        WeightEntry.self,
        PlanSnapshot.self,
        LovedMeal.self,
        LovedMealItem.self,
    ])

    static func makeContainer(inMemory: Bool = false, cloudKit: Bool = AppConfig.useCloudKit) -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }

        if cloudKit {
            do {
                let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                // CloudKit unavailable (no entitlement / not signed in), fall back to local
                // rather than crash. Local is always the resilient base.
                NSLog("Pickle: CloudKit container unavailable (\(error)). Falling back to local store.")
            }
        }

        do {
            let config = ModelConfiguration(schema: schema)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Last resort: never let an unreadable on-disk store crash launch. An in-memory
            // store keeps the app usable (data is not persisted) instead of a hard crash.
            NSLog("Pickle: local store unavailable (\(error)). Falling back to in-memory store.")
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}

/// App-wide configuration read from the bundle. Secrets come from Config/Secrets.xcconfig
/// through Info.plist, never from source.
enum AppConfig {
    /// CloudKit sync. Off for now: on a real device the CloudKit `ModelContainer` setup ran on
    /// the main actor during launch (PickleStore.live) and blocked before the first frame drew,
    /// so the app hung on a black screen. Local-only is the resilient, tested path. Re-enable
    /// once the `iCloud.com.pickle.tracker` container is provisioned for the signing team, then
    /// validate two-device sync on hardware.
    static let useCloudKit = false

    /// Shared App Group for the widget snapshot.
    static let appGroup = "group.com.pickle.tracker"

    /// Proxy base URL (Anthropic + USDA live behind it). Empty means no proxy.
    static var proxyURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "PickleProxyURL") as? String) ?? ""
    }

    static var hasProxy: Bool { !proxyURL.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Direct Anthropic key, testing only (embedded in the binary). Production uses the proxy
    /// so no key ships. Empty means fall back to the proxy or the mock.
    static var anthropicKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "PickleAnthropicKey") as? String) ?? ""
    }

    static var hasAnthropicKey: Bool { !anthropicKey.trimmingCharacters(in: .whitespaces).isEmpty }
}
