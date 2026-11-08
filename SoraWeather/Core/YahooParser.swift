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
              let anchor = html.range(of: "forecastCity", options: .caseInsensitive),
              let issued = HTML.issued(String(html.prefix(upTo: anchor.lowerBound))) else { throw SoraError.invalidData }
        let blocks = city[1].components(separatedBy: "<p class=\"date\">").dropFirst()
        var days: [ForecastDay] = []; var slots: [ForecastSlot] = []
        for block in blocks {
            guard let date = HTML.day(block, near: issued) else { throw SoraError.invalidData }
            guard ForecastRange.contains(date, from: now) else { continue }
            guard let condition = HTML.groups(#"<p class="pict">.*?alt="([^"]+)""#, block).first?[1],
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
                guard let date = HTML.day(rows[0][i], near: issued) else { throw SoraError.invalidData }
                guard ForecastRange.contains(date, from: now) else { continue }
                guard let condition = HTML.groups(#"alt="([^"]+)""#, rows[1][i]).first?[1] else { throw SoraError.invalidData }
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
        guard !slots.isEmpty else { throw SoraError.noForecast }; return (issued, slots.filter { ForecastRange.contains($0.date, from: issued) })
    }
    public static func rain(_ data: Data) throws -> [RainPoint] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["Feature"] as? [[String: Any]],
              let property = features.first?["Property"] as? [String: Any],
              let list = property["WeatherList"] as? [String: Any], let entries = list["Weather"] as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let text = entry["Date"] as? String, let date = JapanTime.date(text, format: "yyyyMMddHHmm"),
                  let kind = entry["Type"] as? String, kind == "forecast" || kind == "observation" else { return nil }
            let number = (entry["Rainfall"] as? NSNumber)?.doubleValue ?? (entry["Rainfall"] as? String).flatMap(Double.init)
            guard let amount = number, amount.isFinite, amount >= 0 else { return nil }
            return RainPoint(date: date, intensity: amount, forecast: kind == "forecast")
        }.sorted { $0.date < $1.date }
    }
}

extension YahooParser {
    // Optional fields are independent. Never align columns when a table row has shifted.
    public static func resilientForecast(_ raw: String, region: Region, now: Date) -> WeatherSnapshot? {
        guard raw.utf8.count <= 2_000_000 else { return nil }
        let html = raw.replacingOccurrences(of: "'", with: "\"")
        guard let issued = HTML.issued(html) else { return nil }
        var days: [ForecastDay] = []; var slots: [ForecastSlot] = []
        let blocks = HTML.groups(#"<p\b[^>]*class\s*=\s*"[^"]*\bdate\b[^"]*"[^>]*>(.*?)(?=<p\b[^>]*class\s*=\s*"[^"]*\bdate\b|id\s*=\s*"yjw_week"|$)"#, html)
        for match in blocks.prefix(2) {
            let block = match[1]
            guard let date = HTML.day(block, near: issued), ForecastRange.contains(date, from: now) else { continue }
            let condition = HTML.groups(#"<p\b[^>]*class\s*=\s*"[^"]*pict[^"]*"[^>]*>.*?alt\s*=\s*"([^"]*)""#, block).first?[1] ?? ""
            let high = HTML.groups(#"class\s*=\s*"[^"]*\bhigh\b[^"]*"[^>]*>\s*<em[^>]*>(.*?)</em>"#, block).first.flatMap { HTML.number($0[1]) }
            let low = HTML.groups(#"class\s*=\s*"[^"]*\blow\b[^"]*"[^>]*>\s*<em[^>]*>(.*?)</em>"#, block).first.flatMap { HTML.number($0[1]) }
            if !condition.isEmpty || high != nil || low != nil { days.append(ForecastDay(date: date, high: high, low: low, probability: nil, condition: condition)) }
            if let row = HTML.groups(#"<tr\b[^>]*class\s*=\s*"[^"]*precip[^"]*"[^>]*>(.*?)</tr>"#, block).first {
                let cells = HTML.groups("<td[^>]*>(.*?)</td>", row[1])
                if cells.count == 4 {
                    for (i, cell) in cells.enumerated() {
                        guard let n = HTML.number(cell[1]), (0...100).contains(n), let start = JapanTime.calendar.date(byAdding: .hour, value: i*6, to: date) else { continue }
                        slots.append(ForecastSlot(date: start, temperature: nil, rainMM: nil, probability: Int(n), condition: condition, durationHours: 6))
                    }
                }
            }
        }
        if let week = HTML.groups(#"id\s*=\s*"yjw_week"(.*?)</table>"#, html).first {
            let rows = HTML.rows(week[1]); let count = rows.first?.count ?? 0
            func cell(_ row: Int, _ col: Int) -> String? {
                let labels = [1: "天気", 2: "気温", 3: "確率"]
                let values: [String]?
                if row == 0 { values = rows.first } else { values = rows.first { r in r.count == count && (r.first.map(HTML.clean)?.contains(labels[row] ?? "__") ?? false) } }
                guard let values, values.indices.contains(col) else { return nil }; return values[col]
            }
            if count > 1 {
                for i in 1..<count {
                    guard let date = cell(0,i).flatMap({ HTML.day($0, near: issued) }), ForecastRange.contains(date, from: now) else { continue }
                    let condition = cell(1,i).flatMap { HTML.groups(#"alt\s*=\s*"([^"]*)""#, $0).first?[1] } ?? ""
                    let temperatureCell = cell(2,i) ?? ""
                    let high = HTML.groups(##"<font[^>]*color\s*=\s*"#?ff3300"[^>]*>(.*?)</font>"##, temperatureCell).first.flatMap { HTML.number($0[1]) }
                    let low = HTML.groups(##"<font[^>]*color\s*=\s*"#?0066ff"[^>]*>(.*?)</font>"##, temperatureCell).first.flatMap { HTML.number($0[1]) }
                    let pop = cell(3,i).flatMap(HTML.number).flatMap { (0...100).contains($0) ? Int($0) : nil }
                    if !condition.isEmpty || high != nil || low != nil || pop != nil { days.append(ForecastDay(date: date, high: high, low: low, probability: pop, condition: condition)) }
                }
            }
        }
        guard !days.isEmpty || !slots.isEmpty else { return nil }
        return WeatherSnapshot(region: region, source: "Yahoo! JAPAN", issued: issued, fetched: now, days: days, slots: slots)
    }
    public static func resilientPinpoint(_ raw: String) -> (Date, [ForecastSlot])? {
        guard raw.utf8.count <= 2_000_000 else { return nil }
        let html = raw.replacingOccurrences(of: "'", with: "\"")
        guard let section = HTML.groups(#"id\s*=\s*"yjw_pinpoint"(.*)"#, html).first, let issued = HTML.issued(section[1]) else { return nil }
        var slots: [ForecastSlot] = []
        for id in ["yjw_pinpoint_today", "yjw_pinpoint_tomorrow"] {
            guard let block = HTML.groups("id\\s*=\\s*\"\(id)\"(.*?)</table>", html).first, let day = HTML.day(block[1], near: issued) else { continue }
            let rows = HTML.rows(block[1]); guard let hours = rows.first, hours.count > 1 else { continue }
            func row(_ label: String) -> [String]? { rows.first { $0.count == hours.count && ($0.first.map(HTML.clean)?.contains(label) ?? false) } }
            let temperatures = row("気温"); let rain = row("降水"); let weather = row("天気")
            for i in 1..<hours.count {
                guard let h = HTML.groups(#"(\d{1,2})時"#, hours[i]).first.flatMap({ Int($0[1]) }), (0...23).contains(h), let date = JapanTime.calendar.date(byAdding: .hour, value: h, to: day) else { continue }
                let temp = temperatures.flatMap { HTML.number($0[i]) }; let amount = rain.flatMap { HTML.number($0[i]) }
                let condition = weather.flatMap { HTML.groups(#"alt\s*=\s*"([^"]*)""#, $0[i]).first?[1] } ?? ""
                if temp != nil || amount != nil || !condition.isEmpty { slots.append(ForecastSlot(date: date, temperature: temp, rainMM: amount, probability: nil, condition: condition, durationHours: 3)) }
            }
        }
        return slots.isEmpty ? nil : (issued, slots.filter { ForecastRange.contains($0.date, from: issued) })
    }
}
