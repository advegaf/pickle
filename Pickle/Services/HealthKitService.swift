import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// A snapshot of the user's body data and recent movement pulled from Apple Health, used to
/// build a sharper plan than a manual form can.
struct BodyProfile: Equatable, Sendable {
    var weightKg: Double?
    var heightCm: Double?
    var leanMassKg: Double?
    var sex: Sex?
    var age: Int?
    var avgDailySteps: Double?
    var avgDailyActiveEnergy: Double?

    var isEmpty: Bool {
        weightKg == nil && heightCm == nil && leanMassKg == nil && sex == nil
            && age == nil && avgDailySteps == nil && avgDailyActiveEnergy == nil
    }

    /// Activity level inferred from average daily steps, cross checked against active energy.
    var inferredActivity: ActivityLevel? {
        if let steps = avgDailySteps, steps > 0 {
            switch steps {
            case ..<5000: return .sedentary
            case ..<7500: return .light
            case ..<10000: return .moderate
            case ..<12500: return .active
            default: return .veryActive
            }
        }
        if let energy = avgDailyActiveEnergy, energy > 0 {
            switch energy {
            case ..<200: return .sedentary
            case ..<400: return .light
            case ..<600: return .moderate
            case ..<800: return .active
            default: return .veryActive
            }
        }
        return nil
    }
}

/// Writes logged energy/macros to Apple Health and reads body composition + movement back.
/// Read-denial is invisible by API (a denied read looks identical to "no data"), so callers
/// treat empty reads as "set up manually" and degrade gracefully.
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published private(set) var isWriteAuthorized = false

    /// Persisted: the user has been through the Apple Health connect flow at least once. The iOS
    /// permission sheet only ever shows once, so after the first grant the app must stop asking.
    private let connectedOnceKey = "healthConnectedOnce"
    var healthConnectedOnce: Bool {
        get { UserDefaults.standard.bool(forKey: connectedOnceKey) }
        set { UserDefaults.standard.set(newValue, forKey: connectedOnceKey) }
    }

    /// True once Health write is authorized OR the user has connected before. Every surface keys
    /// its "connected" state off this so none of them re-prompt after the first connect.
    var hasConnected: Bool { isWriteAuthorized || healthConnectedOnce }

    private init() {
        refreshAuthorization()
    }

    /// Restore the authorization state at launch. Share-type status is reliable (unlike read), so
    /// this reflects a grant from a previous session, which `isWriteAuthorized` (reset to false on
    /// every launch) otherwise forgets, making the app re-prompt to connect forever.
    func refreshAuthorization() {
        #if canImport(HealthKit)
        guard isAvailable else { return }
        isWriteAuthorized = store.authorizationStatus(for: energyType) == .sharingAuthorized
        #endif
    }

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    private var energyType: HKQuantityType { HKQuantityType(.dietaryEnergyConsumed) }
    private var proteinType: HKQuantityType { HKQuantityType(.dietaryProtein) }
    private var carbsType: HKQuantityType { HKQuantityType(.dietaryCarbohydrates) }
    private var fatType: HKQuantityType { HKQuantityType(.dietaryFatTotal) }

    private var weightType: HKQuantityType { HKQuantityType(.bodyMass) }
    private var heightType: HKQuantityType { HKQuantityType(.height) }
    private var leanMassType: HKQuantityType { HKQuantityType(.leanBodyMass) }
    private var stepType: HKQuantityType { HKQuantityType(.stepCount) }
    private var activeEnergyType: HKQuantityType { HKQuantityType(.activeEnergyBurned) }

    private var writeTypes: Set<HKSampleType> { [energyType, proteinType, carbsType, fatType] }
    private var readTypes: Set<HKObjectType> {
        [weightType, heightType, leanMassType, stepType, activeEnergyType,
         HKCharacteristicType(.biologicalSex), HKCharacteristicType(.dateOfBirth)]
    }
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
            healthConnectedOnce = true
            return true
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

    /// Pull weight, height, lean mass, sex, age, and trailing 7 day movement averages.
    func fetchBodyProfile() async -> BodyProfile {
        #if canImport(HealthKit)
        guard isAvailable else { return BodyProfile() }
        async let weight = latestQuantity(weightType, unit: .gramUnit(with: .kilo))
        async let height = latestQuantity(heightType, unit: .meterUnit(with: .centi))
        async let lean = latestQuantity(leanMassType, unit: .gramUnit(with: .kilo))
        async let steps = dailyAverage(stepType, unit: .count(), days: 7)
        async let active = dailyAverage(activeEnergyType, unit: .kilocalorie(), days: 7)

        var profile = BodyProfile(
            weightKg: await weight,
            heightCm: await height,
            leanMassKg: await lean,
            sex: biologicalSex(),
            age: age(),
            avgDailySteps: await steps,
            avgDailyActiveEnergy: await active
        )
        // Guard against absurd height units (Health stores meters; we asked for cm).
        if let h = profile.heightCm, h < 90 || h > 230 { profile.heightCm = nil }
        return profile
        #else
        return BodyProfile()
        #endif
    }

    /// Today's active energy burned in kcal, or nil if unavailable.
    func todayActiveEnergy() async -> Double? {
        #if canImport(HealthKit)
        guard isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        return await sum(activeEnergyType, unit: .kilocalorie(), from: start, to: Date())
        #else
        return nil
        #endif
    }

    #if canImport(HealthKit)
    private func sample(_ type: HKQuantityType, _ unit: HKUnit, _ value: Double, _ date: Date) -> HKQuantitySample {
        HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: max(value, 0)),
                         start: date, end: date)
    }

    private func biologicalSex() -> Sex? {
        guard let raw = try? store.biologicalSex().biologicalSex else { return nil }
        switch raw {
        case .male: return .male
        case .female: return .female
        default: return nil
        }
    }

    private func age() -> Int? {
        guard let dob = try? store.dateOfBirthComponents(),
              let year = dob.year, let month = dob.month, let day = dob.day,
              let birth = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year
        guard let years, years > 0, years < 120 else { return nil }
        return years
    }

    private func latestQuantity(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func dailyAverage(_ type: HKQuantityType, unit: HKUnit, days: Int) async -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        guard let total = await sum(type, unit: unit, from: start, to: Date()), total > 0 else { return nil }
        return total / Double(days)
    }

    private func sum(_ type: HKQuantityType, unit: HKUnit, from: Date, to: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
    #endif
}
