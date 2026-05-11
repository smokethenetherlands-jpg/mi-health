import HealthKit

struct HealthData {
    var steps: Int = 0
    var heartRate: Double = 0
    var calories: Double = 0
    var sleepHours: Double = 0
}

class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    func requestPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis)
        ]
        try? await store.requestAuthorization(toShare: [], read: types)
    }

    func fetchTodayData() async -> HealthData {
        let start = Calendar.current.startOfDay(for: Date())
        return await fetchData(from: start, to: Date())
    }

    func fetchData(from start: Date, to end: Date) async -> HealthData {
        async let steps = fetchSteps(from: start, to: end)
        async let heartRate = fetchHeartRate(from: start, to: end)
        async let calories = fetchCalories(from: start, to: end)
        async let sleep = fetchSleep()
        return await HealthData(steps: steps, heartRate: heartRate, calories: calories, sleepHours: sleep)
    }

    private func fetchSteps(from start: Date, to end: Date) async -> Int {
        await fetchSum(.stepCount, unit: .count(), from: start, to: end).map { Int($0) } ?? 0
    }

    private func fetchHeartRate(from start: Date, to end: Date) async -> Double {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, r, _ in
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0)
            }
            store.execute(q)
        }
    }

    private func fetchCalories(from start: Date, to end: Date) async -> Double {
        await fetchSum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end) ?? 0
    }

    private func fetchSleep() async -> Double {
        let type = HKCategoryType(.sleepAnalysis)
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let all = samples as? [HKCategorySample] ?? []
                let hasPhases = all.contains {
                    [HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                     HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                     HKCategoryValueSleepAnalysis.asleepDeep.rawValue].contains($0.value)
                }
                let wanted: Set<Int> = hasPhases
                    ? [HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                       HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                       HKCategoryValueSleepAnalysis.asleepDeep.rawValue]
                    : [HKCategoryValueSleepAnalysis.asleep.rawValue,
                       HKCategoryValueSleepAnalysis.inBed.rawValue]
                let seconds = all
                    .filter { wanted.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: seconds / 3600)
            }
            store.execute(q)
        }
    }

    private func fetchSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async -> Double? {
        let type = HKQuantityType(id)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, r, _ in
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }
}
