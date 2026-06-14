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
                // CloudKit unavailable (no entitlement / not signed in) — fall back to local
                // rather than crash. Local is always the resilient base.
                NSLog("Pickle: CloudKit container unavailable (\(error)). Falling back to local store.")
            }
        }

        let config = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: config)
    }
}

/// App-wide configuration read from the bundle. The Anthropic key never lives here — only
/// the proxy URL does, and it's empty until the proxy is stood up (Phase 13).
enum AppConfig {
    /// Flip to `true` once the iCloud entitlement + container are wired on a paid account.
    /// Left off so the simulator and CI use the stable local store.
    static let useCloudKit = false

    /// Shared App Group for the widget snapshot.
    static let appGroup = "group.com.pickle.tracker"

    /// Proxy base URL (Anthropic + USDA live behind it). Empty → AI uses the mock and
    /// search uses OFF-direct.
    static var proxyURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "PickleProxyURL") as? String) ?? ""
    }

    static var hasProxy: Bool { !proxyURL.trimmingCharacters(in: .whitespaces).isEmpty }
}
