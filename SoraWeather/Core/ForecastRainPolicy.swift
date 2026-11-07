import Foundation

public enum ForecastRainPolicy {
    public static func window(snapshot: WeatherSnapshot, now: Date) -> ForecastSlot? {
        guard !snapshot.stale(at: now), now.timeIntervalSince(snapshot.fetched) <= 3600 else { return nil }
        return snapshot.slots.sorted { $0.date < $1.date }.first {
            $0.date > now && $0.date <= now.addingTimeInterval(24*3600) && (($0.probability ?? 0) >= 50 || ($0.rainMM ?? 0) >= 0.5)
        }
    }
}
