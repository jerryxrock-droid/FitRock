import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

enum HealthKitAvailabilityStatus {
    case unavailable
    case notDetermined
    case authorized
    case denied
}

protocol HealthMetricsProviding {
    func requestAuthorization(completion: @escaping (Bool) -> Void)
    func fetchSnapshot(completion: @escaping (HealthMetricsSnapshot) -> Void)
}

final class HealthKitService: HealthMetricsProviding {
    static let shared = HealthKitService()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        let types: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        ].compactMap { $0 }.reduce(into: Set<HKObjectType>()) { $0.insert($1) }
        store.requestAuthorization(toShare: [], read: types) { success, _ in
            completion(success)
        }
        #else
        completion(false)
        #endif
    }

    func fetchSnapshot(completion: @escaping (HealthMetricsSnapshot) -> Void) {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.empty)
            return
        }
        let group = DispatchGroup()
        var snapshot = HealthMetricsSnapshot.empty

        group.enter()
        fetchMostRecent(identifier: .bodyMass, unit: .gramUnit(with: .kilo)) {
            snapshot.bodyMassKg = $0
            group.leave()
        }

        group.enter()
        fetchAverage(identifier: .heartRate, unit: HKUnit.count().unitDivided(by: .minute())) {
            snapshot.averageHeartRate = $0
            group.leave()
        }

        group.enter()
        fetchMostRecent(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) {
            snapshot.restingHeartRate = $0
            group.leave()
        }

        group.enter()
        fetchSum(identifier: .activeEnergyBurned, unit: .kilocalorie()) {
            snapshot.activeEnergyKcal30d = $0
            group.leave()
        }

        group.notify(queue: .main) {
            snapshot.capturedAt = Date()
            completion(snapshot)
        }
        #else
        completion(.empty)
        #endif
    }

    #if canImport(HealthKit)
    private func fetchMostRecent(identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            completion(value)
        }
        store.execute(query)
    }

    private func fetchAverage(identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
            completion(stats?.averageQuantity()?.doubleValue(for: unit))
        }
        store.execute(query)
    }

    private func fetchSum(identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
            completion(stats?.sumQuantity()?.doubleValue(for: unit))
        }
        store.execute(query)
    }
    #endif
}
