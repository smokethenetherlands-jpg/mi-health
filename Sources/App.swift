import SwiftUI
import BackgroundTasks

@main
struct HealthBridgeApp: App {
    init() {
        for id in ["com.user.healthbridge.morning", "com.user.healthbridge.evening"] {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
                handleDailyReport(task: task as! BGAppRefreshTask)
            }
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
    scheduleNextReports()
    let t = Task {
        let data = await HealthKitManager.shared.fetchTodayData()
        await TelegramSender.send(data)
        task.setTaskCompleted(success: true)
        UserDefaults.standard.set(Date(), forKey: "lastReportDate")
    }
    task.expirationHandler = { t.cancel() }
}

func scheduleDailyReportIfNeeded() {
    scheduleNextReports()
    Task {
        guard !reportSentRecently() else { return }
        let data = await HealthKitManager.shared.fetchTodayData()
        await TelegramSender.send(data)
        UserDefaults.standard.set(Date(), forKey: "lastReportDate")
    }
}

func scheduleNextReports() {
    let slots: [(String, DateComponents)] = [
        ("com.user.healthbridge.morning", DateComponents(hour: 8, minute: 0)),
        ("com.user.healthbridge.evening", DateComponents(hour: 21, minute: 0))
    ]
    for (id, time) in slots {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = Calendar.current.nextDate(after: Date(), matching: time, matchingPolicy: .nextTime)
        try? BGTaskScheduler.shared.submit(request)
    }
}

// Считаем "уже отправлено" если прошло менее 20 часов — защита от дублей при двух слотах
func reportSentRecently() -> Bool {
    guard let last = UserDefaults.standard.object(forKey: "lastReportDate") as? Date else { return false }
    return Date().timeIntervalSince(last) < 20 * 3600
}
