import Foundation

// Public HTML is not a stable API. Reject incomplete structure instead of aligning wrong columns.
public enum HTML {
    public static func groups(_ pattern: String, _ text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        return re.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { m in
            (0..<m.numberOfRanges).map { Range(m.range(at: $0), in: text).map { String(text[$0]) } ?? "" }
        }
    }
    public static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression).replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func number(_ text: String) -> Double? { Double(clean(text).replacingOccurrences(of: "℃", with: "").replacingOccurrences(of: "％", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) }
    public static func rows(_ text: String) -> [[String]] { groups("<tr\\b[^>]*>(.*?)</tr>", text).map { groups("<td\\b[^>]*>(.*?)</td>", $0[1]).map { $0[1] } } }
    static func issued(_ text: String) -> Date? {
        guard let m = groups(#"(\d{4})年(\d{1,2})月(\d{1,2})日[\s　]*(\d{1,2})時(\d{2})分"#, text).first else { return nil }
        return JapanTime.date("\(m[1])-\(m[2])-\(m[3]) \(m[4]):\(m[5])", format: "yyyy-M-d H:mm")
    }
    static func day(_ text: String, near: Date) -> Date? {
        guard let m = groups(#"(\d{1,2})月(\d{1,2})日"#, text).first, let month = Int(m[1]), let day = Int(m[2]) else { return nil }
        return JapanTime.monthDay(month, day, near: near)
    }
}
public enum YahooParser {
    public static func forecast(_ html: String, region: Region, now: Date) throws -> WeatherSnapshot {
        guard let city = HTML.groups(#"<div class="forecastCity">(.*?)<!-- /forecastToday -->"#, html).first,
              let issued = HTML.issued(String(html.prefix(upTo: html.range(of: "forecastCity")!.lowerBound))) else { throw SoraError.invalidData }
        let blocks = city[1].components(separatedBy: "<p class=\"date\">").dropFirst()
        var days: [ForecastDay] = []; var slots: [ForecastSlot] = []
        for block in blocks {
            guard let date = HTML.day(block, near: issued),
                  let condition = HTML.groups(#"<p class="pict">.*?alt="([^"]+)""#, block).first?[1],
                  let highText = HTML.groups(#"class="high"><em>(.*?)</em>"#, block).first?[1],
                  let lowText = HTML.groups(#"class="low"><em>(.*?)</em>"#, block).first?[1] else { throw SoraError.invalidData }
            // Preserve interval probabilities. A maximum across intervals is not a daily probability.
            if let precip = HTML.groups(#"<tr class="precip">(.*?)</tr>"#, block).first {
                let cells = HTML.groups("<td[^>]*>(.*?)</td>", precip[1])
                guard cells.count == 4 else { throw SoraError.invalidData }
                for (i, cell) in cells.enumerated() {
                    if let probability = HTML.number(cell[1]), (0...100).contains(probability), let start = JapanTime.calendar.date(byAdding: .hour, value: i*6, to: date) {
                        slots.append(ForecastSlot(date: start, temperature: nil, rainMM: nil, probability: Int(probability), condition: condition, durationHours: 6))
                    }
                }
            }
            days.append(ForecastDay(date: date, high: HTML.number(highText), low: HTML.number(lowText), probability: nil, condition: condition))
        }
        if let week = HTML.groups(#"id="yjw_week"(.*?)</table>"#, html).first {
            let rows = HTML.rows(week[1]); guard rows.count >= 4 else { throw SoraError.invalidData }
            let count = rows[0].count
            guard count > 1, rows.prefix(4).allSatisfy({ $0.count == count }) else { throw SoraError.invalidData }
            for i in 1..<count {
                guard let date = HTML.day(rows[0][i], near: issued), let condition = HTML.groups(#"alt="([^"]+)""#, rows[1][i]).first?[1] else { throw SoraError.invalidData }
                let temps = HTML.groups(#"<font[^>]*>(.*?)</font>"#, rows[2][i]).map { HTML.number($0[1]) }
                guard temps.count == 2 else { throw SoraError.invalidData }
                days.append(ForecastDay(date: date, high: temps[0], low: temps[1], probability: HTML.number(rows[3][i]).map(Int.init), condition: condition))
            }
        }
        guard !days.isEmpty else { throw SoraError.noForecast }
        return WeatherSnapshot(region: region, source: "Yahoo! JAPAN", issued: issued, fetched: now, days: days, slots: slots)
    }
    public static func pinpoint(_ html: String) throws -> (Date, [ForecastSlot]) {
        guard let section = HTML.groups(#"id="yjw_pinpoint"(.*)"#, html).first, let issued = HTML.issued(section[1]) else { throw SoraError.invalidData }
        var slots: [ForecastSlot] = []
        for id in ["yjw_pinpoint_today", "yjw_pinpoint_tomorrow"] {
            guard let block = HTML.groups("id=\"\(id)\"(.*?)</table>", html).first, let day = HTML.day(block[1], near: issued) else { continue }
            let rows = HTML.rows(block[1])
            guard rows.count >= 5, rows[0].count > 1, rows.prefix(5).allSatisfy({ $0.count == rows[0].count }), HTML.clean(rows[2][0]).contains("気温"), HTML.clean(rows[4][0]).contains("降水") else { throw SoraError.invalidData }
            for i in 1..<rows[0].count {
                guard let h = HTML.groups(#"(\d{1,2})時"#, rows[0][i]).first.flatMap({ Int($0[1]) }), (0...23).contains(h),
                      let date = JapanTime.calendar.date(byAdding: .hour, value: h, to: day),
                      let condition = HTML.groups(#"alt="([^"]+)""#, rows[1][i]).first?[1] else { throw SoraError.invalidData }
                slots.append(ForecastSlot(date: date, temperature: HTML.number(rows[2][i]), rainMM: HTML.number(rows[4][i]), probability: nil, condition: condition, durationHours: 3))
            }
        }
        guard !slots.isEmpty else { throw SoraError.noForecast }; return (issued, slots)
    }
    public static func rain(_ data: Data) throws -> [RainPoint] {
        struct Envelope: Decodable { let Feature: [Feature] }
        struct Feature: Decodable { let Property: Property }
        struct Property: Decodable { let WeatherList: WeatherList }
        struct WeatherList: Decodable { let Weather: [Entry] }
        struct Entry: Decodable { let `Type`: String; let Date: String; let Rainfall: Double }
        let root = try JSONDecoder().decode(Envelope.self, from: data)
        guard let first = root.Feature.first else { throw SoraError.invalidData }
        return first.Property.WeatherList.Weather.compactMap { e in
            guard let date = JapanTime.date(e.Date, format: "yyyyMMddHHmm"), e.Rainfall >= 0, e.Type == "forecast" || e.Type == "observation" else { return nil }
            return RainPoint(date: date, intensity: e.Rainfall, forecast: e.Type == "forecast")
        }.sorted { $0.date < $1.date }
    }
}
