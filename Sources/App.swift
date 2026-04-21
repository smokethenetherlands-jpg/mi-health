import SwiftUI
import BackgroundTasks

@main
struct HealthBridgeApp: App {
    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.user.healthbridge.daily", using: nil) { task in
            handleDailyReport(task: task as! BGAppRefreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    scheduleDailyReportIfNeeded()
                }
        }
    }
}

func handleDailyReport(task: BGAppRefreshTask) {
    scheduleNextDailyReport()
    let t = Task {
        let data = await HealthKitManager.shared.fetchTodayData()
        await TelegramSender.send(data)
        task.setTaskCompleted(success: true)
        UserDefaults.standard.set(Date(), forKey: "lastReportDate")
    }
    task.expirationHandler = { t.cancel() }
}

func scheduleDailyReportIfNeeded() {
    scheduleNextDailyReport()
    Task {
        guard !reportSentToday() else { return }
        let data = await HealthKitManager.shared.fetchTodayData()
        await TelegramSender.send(data)
        UserDefaults.standard.set(Date(), forKey: "lastReportDate")
    }
}

func scheduleNextDailyReport() {
    let request = BGAppRefreshTaskRequest(identifier: "com.user.healthbridge.daily")
    request.earliestBeginDate = Calendar.current.nextDate(
        after: Date(),
        matching: DateComponents(hour: 8, minute: 0),
        matchingPolicy: .nextTime
    )
    try? BGTaskScheduler.shared.submit(request)
}

func reportSentToday() -> Bool {
    guard let last = UserDefaults.standard.object(forKey: "lastReportDate") as? Date else { return false }
    return Calendar.current.isDateInToday(last)
}
