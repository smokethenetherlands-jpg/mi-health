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
                    scheduleDailyReportsIfNeeded()
                }
        }
    }
}

func handleDailyReport(task: BGAppRefreshTask) {
    let isMorning = task.identifier == "com.user.healthbridge.morning"
    scheduleNextReports()
    let t = Task {
        if isMorning { await sendMorningReport() } else { await sendEveningReport() }
        task.setTaskCompleted(success: true)
    }
    task.expirationHandler = { t.cancel() }
}

func scheduleDailyReportsIfNeeded() {
    scheduleNextReports()
    Task {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 8  { await sendMorningReport() }
        if hour >= 21 { await sendEveningReport() }
    }
}

func sendMorningReport() async {
    guard !reportSentToday(key: "lastMorningReport") else { return }
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: Date())
    let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!
    let data = await HealthKitManager.shared.fetchData(from: yesterdayStart, to: todayStart)
    await TelegramSender.send(data, title: "\(formatDate(yesterdayStart)) · итог дня")
    UserDefaults.standard.set(Date(), forKey: "lastMorningReport")
}

func sendEveningReport() async {
    guard !reportSentToday(key: "lastEveningReport") else { return }
    let data = await HealthKitManager.shared.fetchData(from: Calendar.current.startOfDay(for: Date()), to: Date())
    await TelegramSender.send(data, title: "\(formatDate(Date())) · сводка")
    UserDefaults.standard.set(Date(), forKey: "lastEveningReport")
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

func reportSentToday(key: String) -> Bool {
    guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return false }
    return Calendar.current.isDateInToday(last)
}

func formatDate(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "ru_RU")
    fmt.dateFormat = "d MMMM"
    return fmt.string(from: date)
}
