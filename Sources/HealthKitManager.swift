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
        async let steps = fetchSteps()
        async let heartRate = fetchHeartRate()
        async let calories = fetchCalories()
        async let sleep = fetchSleep()
        return await HealthData(steps: steps, heartRate: heartRate, calories: calories, sleepHours: sleep)
    }

    private func fetchSteps() async -> Int {
        await fetchSum(.stepCount, unit: .count()).map { Int($0) } ?? 0
    }

    private func fetchHeartRate() async -> Double {
        let type = HKQuantityType(.heartRate)
        let predicate = todayPredicate()
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, r, _ in
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0)
            }
            store.execute(q)
        }
    }

    private func fetchCalories() async -> Double {
        await fetchSum(.activeEnergyBurned, unit: .kilocalorie()) ?? 0
    }

    private func fetchSleep() async -> Double {
        let type = HKCategoryType(.sleepAnalysis)
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleep: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                ]
                let seconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleep.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: seconds / 3600)
            }
            store.execute(q)
        }
    }

    private func fetchSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(id)
        let predicate = todayPredicate()
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, r, _ in
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    private func todayPredicate() -> NSPredicate {
        HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
    }
}
