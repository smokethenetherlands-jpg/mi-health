import Foundation

struct TelegramSender {
    private static let token = "8585115512:AAHQ3ZoxNJ4HFOSX1kP7fFSoA7zIWy2X8QA"
    private static let chatID = "597323588"

    static func send(_ data: HealthData) async {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        let text = """
📊 Отчёт за \(date)

👟 Шаги: \(data.steps.formatted())
❤️ Пульс: \(data.heartRate > 0 ? "\(Int(data.heartRate)) уд/мин" : "нет данных")
🔥 Калории: \(data.calories > 0 ? "\(Int(data.calories)) ккал" : "нет данных")
😴 Сон: \(data.sleepHours > 0 ? String(format: "%.1f ч", data.sleepHours) : "нет данных")
"""
        var req = URLRequest(url: URL(string: "https://api.telegram.org/bot\(token)/sendMessage")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["chat_id": chatID, "text": text])
        _ = try? await URLSession.shared.data(for: req)
    }
}
