import SwiftUI
import UserNotifications

@main
struct HealthBridgeApp: App {
    init() {
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    scheduleNotifications()
                    scheduleDailyReportsIfNeeded()
                }
        }
    }
}

func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
}

func scheduleNotifications() {
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    let slots: [(String, Int, String)] = [
        ("morning", 8,  "Итог вчерашнего дня"),
        ("evening", 21, "Сводка за сегодня")
    ]
    for (id, hour, body) in slots {
        let content = UNMutableNotificationContent()
        content.title = "HealthBridge"
        content.body = body
        content.sound = .default
        var dc = DateComponents()
        dc.hour = hour
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

func scheduleDailyReportsIfNeeded() {
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
    guard data.steps > 0 || data.heartRate > 0 || data.calories > 0 else { return }
    await TelegramSender.send(data, title: "\(formatDate(yesterdayStart)) · итог дня")
    UserDefaults.standard.set(Date(), forKey: "lastMorningReport")
}

func sendEveningReport() async {
    guard !reportSentToday(key: "lastEveningReport") else { return }
    let data = await HealthKitManager.shared.fetchData(from: Calendar.current.startOfDay(for: Date()), to: Date())
    guard data.steps > 0 || data.heartRate > 0 || data.calories > 0 else { return }
    await TelegramSender.send(data, title: "\(formatDate(Date())) · сводка")
    UserDefaults.standard.set(Date(), forKey: "lastEveningReport")
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
