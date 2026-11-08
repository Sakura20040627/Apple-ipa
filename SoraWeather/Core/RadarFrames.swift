import Foundation

public struct RadarFrame: Identifiable, Equatable, Sendable {
    public let base: String
    public let valid: String
    public let date: Date
    public var id: String { base + "-" + valid }
    public var forecast: Bool { valid > base }
    public init?(base: String, valid: String) {
        func parse(_ s: String) -> Date? {
            guard s.utf8.count == 14, s.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyyMMddHHmmss"; f.isLenient = false
            guard let d = f.date(from: s), f.string(from: d) == s else { return nil }; return d
        }
        guard let b = parse(base), let d = parse(valid), d >= b, d.timeIntervalSince(b) <= 3600 else { return nil }
        self.base = base; self.valid = valid; date = d
    }
    public func tileURL(z: Int, x: Int, y: Int) -> URL? {
        guard [4, 6, 8, 10].contains(z), x >= 0, y >= 0, x < 1 << z, y < 1 << z else { return nil }
        return URL(string: "https://www.jma.go.jp/bosai/jmatile/data/nowc/\(base)/none/\(valid)/surf/hrpns/\(z)/\(x)/\(y).png")
    }
}
public enum RadarTimeline {
    public static func parse(_ data: Data) throws -> [RadarFrame] {
        guard data.count <= 1_000_000, let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw SoraError.invalidData }
        return rows.compactMap { row in
            guard (row["elements"] as? [String])?.contains("hrpns") == true, let b = row["basetime"] as? String, let v = row["validtime"] as? String else { return nil }
            return RadarFrame(base: b, valid: v)
        }
    }
    public static func window(observed: [RadarFrame], predicted: [RadarFrame], now: Date) -> [RadarFrame] {
        let history = observed.filter { !$0.forecast && $0.date <= now.addingTimeInterval(600) }.sorted { $0.date < $1.date }
        guard let latest = history.last, abs(latest.date.timeIntervalSince(now)) < 1800 else { return [] }
        let future = predicted.filter { $0.base == latest.base && $0.date > latest.date }.sorted { $0.date < $1.date }
        var seen = Set<Date>()
        return (Array(history.suffix(13)) + Array(future.prefix(12))).filter { seen.insert($0.date).inserted }
    }
}
public enum WarningLevel: Int, Comparable, Sendable {
    case advisory, warning, special
    public static func < (lhs: WarningLevel, rhs: WarningLevel) -> Bool { lhs.rawValue < rhs.rawValue }
    public static func level(for item: DisasterItem) -> WarningLevel {
        if item.title.contains("特別警報") { return .special }
        return item.title.contains("警報") ? .warning : .advisory
    }
}
public enum RadarPalette {
    // Verified JMA PNG palette: <1, 1, 5, 10, 20, 30, 50, 80+ mm/h.
    public static let source: [UInt32] = [0xf2f2ff, 0xa0d2ff, 0x218cff, 0x0041ff, 0xfaf500, 0xff9900, 0xff2800, 0xb40068]
    public static let display: [UInt32] = [0x9bdaff, 0x36b2ff, 0x3678f6, 0x7854db, 0xa65bd3, 0xcc78b0, 0xf4b65b, 0xffe563]
    public static let thresholds = ["<1", "1", "5", "10", "20", "30", "50", "80+"]
    public static let mapping: [UInt32: UInt32] = {
        var values = Dictionary(uniqueKeysWithValues: zip(source, display))
        values[0xfff500] = display[4] // Official SVG legend uses 255 instead of PNG palette 250.
        return values
    }()
}
