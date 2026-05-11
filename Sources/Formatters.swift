func formatSleep(_ hours: Double) -> String {
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return m > 0 ? "\(h) ч \(m) мин" : "\(h) ч"
}
