import Foundation

public struct RainPlan: Equatable, Sendable {
    public let id: String
    public let fireDate: Date
    public let onset: Date
}
public enum RainPolicy {
    // One replaceable request per selected region. No critical/time-sensitive entitlement.
    public static func plan(points: [RainPoint], fetched: Date, now: Date, region: String, enabled: Bool, authorized: Bool, lastDelivered: Date?) -> RainPlan? {
        guard enabled, authorized, now.timeIntervalSince(fetched) >= -60, now.timeIntervalSince(fetched) <= 15*60,
              lastDelivered.map({ now.timeIntervalSince($0) >= 60*60 }) ?? true else { return nil }
        let sorted = points.sorted { $0.date < $1.date }
        // Do not report an onset when the latest observation already says rain.
        if let current = sorted.last(where: { !$0.forecast && $0.date <= now }), now.timeIntervalSince(current.date) <= 20*60, current.intensity >= 0.5 { return nil }
        guard let wet = sorted.first(where: { $0.forecast && $0.date > now && $0.date <= now.addingTimeInterval(3600) && $0.intensity >= 0.5 }) else { return nil }
        return RainPlan(id: "rain.\(region)", fireDate: max(now.addingTimeInterval(5), wet.date.addingTimeInterval(-600)), onset: wet.date)
    }
}
