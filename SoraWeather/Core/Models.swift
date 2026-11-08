import Foundation

public enum SoraError: Error { case invalidData, noForecast, http(Int), tooLarge }
public enum JapanTime {
    public static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    public static func iso(_ text: String) -> Date? { ISO8601DateFormatter().date(from: text) }
    public static func date(_ text: String, format: String) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = format; f.isLenient = false
        return f.date(from: text)
    }
    public static func monthDay(_ month: Int, _ day: Int, near reference: Date) -> Date? {
        let year = calendar.component(.year, from: reference)
        return (-1...1).compactMap { calendar.date(from: DateComponents(year: year + $0, month: month, day: day)) }.min { abs($0.timeIntervalSince(reference)) < abs($1.timeIntervalSince(reference)) }
    }
    public static func key(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
public struct Region: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let yahooPath: String
    public let pinpoint: String
    public let office: String
    public let forecastArea: String
    public let station: String
    public var yahooURL: URL { URL(string: "https://weather.yahoo.co.jp/weather/jp/\(yahooPath).html")! }
    public var pinpointURL: URL { URL(string: "https://weather.yahoo.co.jp/weather/jp/\(yahooPath)/\(pinpoint).html")! }
    public static let supported: [Region] = [
        .init(id: "osaka", name: "大阪", latitude: 34.69, longitude: 135.50, yahooPath: "27/6200", pinpoint: "27120", office: "270000", forecastArea: "270000", station: "62078"),
        .init(id: "tokyo", name: "東京", latitude: 35.68, longitude: 139.76, yahooPath: "13/4410", pinpoint: "13101", office: "130000", forecastArea: "130010", station: "44132"),
        .init(id: "kyoto", name: "京都", latitude: 35.01, longitude: 135.77, yahooPath: "26/6110", pinpoint: "26106", office: "260000", forecastArea: "260010", station: "61286"),
        .init(id: "kobe", name: "神戸", latitude: 34.69, longitude: 135.20, yahooPath: "28/6310", pinpoint: "28110", office: "280000", forecastArea: "280010", station: "63518"),
        .init(id: "nagoya", name: "名古屋", latitude: 35.18, longitude: 136.91, yahooPath: "23/5110", pinpoint: "23106", office: "230000", forecastArea: "230010", station: "51106"),
        .init(id: "fukuoka", name: "福岡", latitude: 33.59, longitude: 130.40, yahooPath: "40/8210", pinpoint: "40133", office: "400000", forecastArea: "400010", station: "82182")
    ]
    public static var osaka: Region { supported[0] }
    // Forecast regions are deliberately explicit. Never label Osaka as the GPS position.
    public static func nearest(latitude: Double, longitude: Double) -> Region? {
        func km(_ r: Region) -> Double { let a = (latitude-r.latitude)*111; let b = (longitude-r.longitude)*111*cos(latitude * .pi/180); return sqrt(a*a+b*b) }
        guard let r = supported.min(by: { km($0) < km($1) }), km(r) <= 45 else { return nil }; return r
    }
}
public struct ForecastSlot: Codable, Identifiable, Equatable, Sendable {
    public var id: String { "\(date.timeIntervalSince1970)-\(durationHours)" }
    public let date: Date
    public let temperature: Double?
    public let rainMM: Double?
    public let probability: Int?
    public let condition: String
    public let durationHours: Int
    public init(date: Date, temperature: Double?, rainMM: Double?, probability: Int?, condition: String, durationHours: Int) { self.date=date; self.temperature=temperature; self.rainMM=rainMM; self.probability=probability; self.condition=condition; self.durationHours=durationHours }
}
public struct ForecastDay: Codable, Identifiable, Equatable, Sendable {
    public var id: String { JapanTime.key(date) }
    public let date: Date
    public var high: Double?
    public var low: Double?
    public var probability: Int?
    public var condition: String
}
public enum ForecastRange {
    public static func contains(_ date: Date, from now: Date) -> Bool {
        let start = JapanTime.calendar.startOfDay(for: now)
        guard let end = JapanTime.calendar.date(byAdding: .day, value: 7, to: start) else { return false }
        return date >= start && date < end
    }
    public static func days(_ values: [ForecastDay], from now: Date) -> [ForecastDay] {
        var seen = Set<String>()
        return values.sorted { $0.date < $1.date }.filter {
            contains($0.date, from: now) && (!$0.condition.isEmpty || $0.high != nil || $0.low != nil || $0.probability != nil) && seen.insert($0.id).inserted
        }
    }
}
public struct WeatherSnapshot: Codable, Sendable {
    public let region: Region
    public let source: String
    public let issued: Date
    public let fetched: Date
    public let days: [ForecastDay]
    public let slots: [ForecastSlot]
    public func stale(at now: Date) -> Bool { now.timeIntervalSince(issued) > 6*3600 || issued.timeIntervalSince(now) > 600 }
    public init(region: Region, source: String, issued: Date, fetched: Date, days: [ForecastDay], slots: [ForecastSlot]) {
        self.region = region; self.source = source; self.issued = issued; self.fetched = fetched
        self.days = ForecastRange.days(days, from: fetched)
        self.slots = slots.filter { ForecastRange.contains($0.date, from: fetched) }.sorted { $0.date < $1.date }
    }
    private enum CodingKeys: String, CodingKey { case region, source, issued, fetched, days, slots }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(region: try c.decode(Region.self, forKey: .region), source: try c.decode(String.self, forKey: .source), issued: try c.decode(Date.self, forKey: .issued), fetched: try c.decode(Date.self, forKey: .fetched), days: try c.decode([ForecastDay].self, forKey: .days), slots: try c.decode([ForecastSlot].self, forKey: .slots))
    }
    public func sevenDays(from now: Date) -> [ForecastDay] { ForecastRange.days(days, from: now) }
    public func limited(to now: Date) -> WeatherSnapshot {
        WeatherSnapshot(region: region, source: source, issued: issued, fetched: fetched, days: sevenDays(from: now), slots: slots.filter { ForecastRange.contains($0.date, from: now) })
    }
}
public struct RainPoint: Codable, Equatable, Sendable {
    public let date: Date
    public let intensity: Double
    public let forecast: Bool
}
public struct DisasterItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let issued: Date
}
public enum Condition {
    public static func symbol(_ text: String) -> String {
        if text.isEmpty || text.contains("天気コード") { return "questionmark.circle" }
        if text.contains("雪") { return "cloud.snow.fill" }
        if text.contains("雷") { return "cloud.bolt.rain.fill" }
        if text.contains("雨") { return "cloud.rain.fill" }
        if text.contains("晴") && (text.contains("曇") || text.contains("くもり")) { return "cloud.sun.fill" }
        if text.contains("晴") { return "sun.max.fill" }
        return "cloud.fill"
    }
}

public enum AppLanguage {
    public static var code: String { Locale.preferredLanguages.first?.lowercased().hasPrefix("ja") == true ? "ja" : "zh-Hans" }
}
public enum WeatherMerge {
    public static func combine(primary: WeatherSnapshot, supplement: WeatherSnapshot?) -> WeatherSnapshot {
        guard let extra = supplement, extra.region == primary.region, !extra.stale(at: primary.fetched) else { return primary }
        var days = primary.days
        for day in extra.days {
            if let i = days.firstIndex(where: { $0.id == day.id }) {
                if days[i].high == nil { days[i].high = day.high }
                if days[i].low == nil { days[i].low = day.low }
                if days[i].probability == nil { days[i].probability = day.probability }
                if days[i].condition.isEmpty { days[i].condition = day.condition }
            } else { days.append(day) }
        }
        var slots = primary.slots
        for slot in extra.slots {
            if let i = slots.firstIndex(where: { $0.id == slot.id }) {
                let base = slots[i]
                slots[i] = ForecastSlot(date: base.date, temperature: base.temperature ?? slot.temperature, rainMM: base.rainMM ?? slot.rainMM, probability: base.probability ?? slot.probability, condition: base.condition.isEmpty ? slot.condition : base.condition, durationHours: base.durationHours)
            } else { slots.append(slot) }
        }
        return WeatherSnapshot(region: primary.region, source: "JMA + Yahoo! JAPAN", issued: primary.issued, fetched: primary.fetched, days: days.sorted { $0.date < $1.date }, slots: slots.sorted { $0.date < $1.date })
    }
}
