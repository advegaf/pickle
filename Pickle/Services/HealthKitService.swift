import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Writes logged energy/macros to Apple Health and reads body weight back for the adaptive
/// plan. Read-denial is invisible by API (a denied read looks identical to "no data"), so
/// callers detect "queried, got zero samples" and degrade gracefully rather than mislead.
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published private(set) var isWriteAuthorized = false

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    private var energyType: HKQuantityType { HKQuantityType(.dietaryEnergyConsumed) }
    private var proteinType: HKQuantityType { HKQuantityType(.dietaryProtein) }
    private var carbsType: HKQuantityType { HKQuantityType(.dietaryCarbohydrates) }
    private var fatType: HKQuantityType { HKQuantityType(.dietaryFatTotal) }
    private var weightType: HKQuantityType { HKQuantityType(.bodyMass) }

    private var writeTypes: Set<HKSampleType> { [energyType, proteinType, carbsType, fatType] }
    private var readTypes: Set<HKObjectType> { [weightType] }
    #endif

    var isAvailable: Bool {
        #if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }

    func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isWriteAuthorized = store.authorizationStatus(for: energyType) == .sharingAuthorized
            return isWriteAuthorized
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    /// Mirror a logged entry into Apple Health. Fire-and-forget; failures never block logging.
    func write(macros: MacroTargets, date: Date) {
        #if canImport(HealthKit)
        guard isAvailable, store.authorizationStatus(for: energyType) == .sharingAuthorized else { return }
        let samples: [HKQuantitySample] = [
            sample(energyType, .kilocalorie(), Double(macros.kcal), date),
            sample(proteinType, .gram(), Double(macros.proteinG), date),
            sample(carbsType, .gram(), Double(macros.carbsG), date),
            sample(fatType, .gram(), Double(macros.fatG), date),
        ]
        store.save(samples) { _, _ in }
        #endif
    }

    /// Latest body-weight reading in kg, or nil if none / read not granted. `(value, denied)`
    /// — `denied` distinguishes "no samples because not granted" is impossible to know, so we
    /// simply report nil and let the UI offer manual entry.
    func latestWeightKg() async -> Double? {
        #if canImport(HealthKit)
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
        #else
        return nil
        #endif
    }

    #if canImport(HealthKit)
    private func sample(_ type: HKQuantityType, _ unit: HKUnit, _ value: Double, _ date: Date) -> HKQuantitySample {
        HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: max(value, 0)),
                         start: date, end: date)
    }
    #endif
}
