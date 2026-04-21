import SwiftUI

struct ContentView: View {
    @State private var data = HealthData()
    @State private var status = ""
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                Section("Сегодня") {
                    StatRow(icon: "figure.walk", color: .green, label: "Шаги", value: loading ? "—" : data.steps.formatted())
                    StatRow(icon: "heart.fill", color: .red, label: "Пульс", value: loading ? "—" : data.heartRate > 0 ? "\(Int(data.heartRate)) уд/мин" : "нет данных")
                    StatRow(icon: "flame.fill", color: .orange, label: "Калории", value: loading ? "—" : data.calories > 0 ? "\(Int(data.calories)) ккал" : "нет данных")
                    StatRow(icon: "moon.fill", color: .indigo, label: "Сон", value: loading ? "—" : data.sleepHours > 0 ? String(format: "%.1f ч", data.sleepHours) : "нет данных")
                }

                Section {
                    Button {
                        Task {
                            status = "Отправляю..."
                            await TelegramSender.send(data)
                            UserDefaults.standard.set(Date(), forKey: "lastReportDate")
                            status = "Отправлено ✓"
                        }
                    } label: {
                        Label("Отправить в Telegram", systemImage: "paperplane.fill")
                    }

                    if !status.isEmpty {
                        Text(status).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("HealthBridge")
            .task {
                await HealthKitManager.shared.requestPermissions()
                data = await HealthKitManager.shared.fetchTodayData()
                loading = false
            }
        }
    }
}

struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
