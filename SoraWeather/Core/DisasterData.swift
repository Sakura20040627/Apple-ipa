import Foundation

public enum WarningLevel: Int, CaseIterable, Comparable, Sendable {
    case advisory, warning, special
    public static func < (lhs: WarningLevel, rhs: WarningLevel) -> Bool { lhs.rawValue < rhs.rawValue }
    public static func level(for item: DisasterItem) -> WarningLevel {
        if item.title.contains("特別警報") { return .special }
        return item.title.contains("警報") ? .warning : .advisory
    }
    public var name: String {
        let ja = AppLanguage.code == "ja"
        switch self {
        case .advisory: return ja ? "注意報" : "注意报"
        case .warning: return ja ? "警報" : "警报"
        case .special: return ja ? "特別警報" : "特别警报"
        }
    }
}
public struct SafetyRecord: Codable, Sendable {
    public var warnings: [DisasterItem] = []
    public var quakes: [DisasterItem] = []
    public var warningsIssued: Date?
    public var warningsFetched: Date?
    public var quakesFetched: Date?
    public var warningsOffline = true
    public var quakesOffline = true
    public init() {}
    public var updated: Date? { [warningsFetched, quakesFetched].compactMap { $0 }.min() }
    public var offline: Bool { warningsOffline || quakesOffline }
    public mutating func merge(warnings: [DisasterItem], quakes: [DisasterItem], issued: Date?, warningTime: Date?, quakeTime: Date?) {
        if let time = warningTime, time >= (warningsFetched ?? .distantPast) {
            var seen = Set<String>()
            self.warnings = warnings.filter { seen.insert($0.id).inserted }
            warningsIssued = issued; warningsFetched = time; warningsOffline = false
        } else if warningTime == nil { warningsOffline = true }
        if let time = quakeTime, time >= (quakesFetched ?? .distantPast) {
            var seen = Set<String>()
            self.quakes = Array(quakes.sorted { $0.issued > $1.issued }.filter { seen.insert($0.id).inserted }.prefix(10))
            quakesFetched = time; quakesOffline = false
        } else if quakeTime == nil { quakesOffline = true }
    }
    public func restored() -> SafetyRecord { var value = self; value.warningsOffline = true; value.quakesOffline = true; return value }
}
public struct EarthquakePresentation: Sendable {
    public let location: String
    public let magnitude: String
    public let intensity: String
    public let occurred: Date?
    public init(_ item: DisasterItem) {
        location = item.title.isEmpty ? "JMA" : item.title
        let parts = item.detail.components(separatedBy: " · ")
        let number = parts.first?.replacingOccurrences(of: "M ", with: "").trimmingCharacters(in: .whitespaces) ?? ""
        magnitude = number.isEmpty ? "—" : number
        intensity = parts.count > 1 ? parts[1].replacingOccurrences(of: "最大震度 ", with: "") : "—"
        occurred = parts.count > 2 ? JapanTime.iso(parts[2]) : nil
    }
    public var intensityRank: Int {
        switch intensity {
        case "1": return 1; case "2": return 2; case "3": return 3; case "4": return 4
        case "5-", "5弱": return 5; case "5+", "5強": return 6
        case "6-", "6弱": return 7; case "6+", "6強": return 8; case "7": return 9
        default: return 0
        }
    }
    public var intensityLabel: String { intensity.replacingOccurrences(of: "-", with: "弱").replacingOccurrences(of: "+", with: "強") }
}
public enum SafetyDestination {
    public static func cityKey(userInfo: [AnyHashable: Any], identifier: String) -> String? {
        for key in ["cityID", "regionID", "region"] {
            if let value = userInfo[key] as? String, !value.isEmpty, value.count < 128 { return value }
        }
        let parts = identifier.split(separator: ".")
        if parts.count >= 3, parts[0] == "rain" { return parts.dropFirst().dropLast().joined(separator: ".") }
        return nil
    }
}
