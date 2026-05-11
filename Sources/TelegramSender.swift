import Foundation

struct TelegramSender {
    private static let token = "8585115512:AAHQ3ZoxNJ4HFOSX1kP7fFSoA7zIWy2X8QA"
    private static let chatID = "597323588"

    static func send(_ data: HealthData) async {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMMM"
        let date = fmt.string(from: Date())

        let steps = data.steps > 0 ? data.steps.formatted() : "—"
        let pulse = data.heartRate > 0 ? "\(Int(data.heartRate)) уд/мин" : "—"
        let kcal  = data.calories > 0 ? "\(Int(data.calories)) ккал" : "—"
        let sleep = data.sleepHours > 0 ? formatSleep(data.sleepHours) : "—"

        let text = """
<b>\(date) · сводка</b>
<blockquote><tg-emoji emoji-id="5368747224949857891">🏃‍♂️</tg-emoji> \(steps) шагов
<tg-emoji emoji-id="5462939542833086234">🥰</tg-emoji> \(pulse)
<tg-emoji emoji-id="5452019171871177378">🍊</tg-emoji> \(kcal)
<tg-emoji emoji-id="5301178881053565108">😴</tg-emoji> \(sleep)</blockquote>
"""
        var req = URLRequest(url: URL(string: "https://api.telegram.org/bot\(token)/sendMessage")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "chat_id": chatID,
            "text": text,
            "parse_mode": "HTML"
        ])
        _ = try? await URLSession.shared.data(for: req)
    }
}
