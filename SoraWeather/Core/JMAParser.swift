import Foundation

public enum JMAParser {
    struct Area: Decodable { let name: String; let code: String }
    struct Forecast: Decodable { let reportDatetime: String; let timeSeries: [Series] }
    struct Series: Decodable { let timeDefines: [String]; let areas: [Values] }
    struct Values: Decodable {
        let area: Area
        let weatherCodes: [String]?
        let weathers: [String]?
        let pops: [String]?
        let temps: [String]?
        let tempsMin: [String]?
        let tempsMax: [String]?
    }
    static func at(_ values: [String]?, _ index: Int) -> String? { guard let values, values.indices.contains(index) else { return nil }; return values[index] }
    static func number(_ values: [String]?, _ index: Int) -> Double? { at(values, index).flatMap(Double.init) }
    public static func forecast(_ data: Data, region: Region, now: Date) throws -> WeatherSnapshot {
        let forecasts = try JSONDecoder().decode([Forecast].self, from: data)
        guard let first = forecasts.first, let issued = JapanTime.iso(first.reportDatetime) else { throw SoraError.invalidData }
        var days: [String: ForecastDay] = [:]; var slots: [ForecastSlot] = []
        for forecast in forecasts {
            for series in forecast.timeSeries {
                // No positional first-area selection: codes are mandatory to prevent cross-region mixing.
                for values in series.areas where [region.forecastArea, region.station, region.office].contains(values.area.code) {
                    for (i, text) in series.timeDefines.enumerated() {
                        guard let date = JapanTime.iso(text) else { throw SoraError.invalidData }
                        guard ForecastRange.contains(date, from: now) else { continue }
                        let key = JapanTime.key(date)
                        var day = days[key] ?? ForecastDay(date: JapanTime.calendar.startOfDay(for: date), high: nil, low: nil, probability: nil, condition: "")
                        if day.condition.isEmpty { day.condition = at(values.weathers, i) ?? codeDescription(at(values.weatherCodes, i) ?? "") }
                        if let n = number(values.tempsMin, i) { day.low = n }
                        if let n = number(values.tempsMax, i) { day.high = n }
                        // Short-range temps contains explicit 00:00 minimum and 09:00 maximum forecasts, not observations.
                        if let n = number(values.temps, i) {
                            let hour = JapanTime.calendar.component(.hour, from: date)
                            if hour == 0 { day.low = n }; if hour == 9 { day.high = n }
                        }
                        if let pop = number(values.pops, i), (0...100).contains(pop) {
                            if forecast.timeSeries.count == 2 { day.probability = Int(pop) }
                            else { slots.append(ForecastSlot(date: date, temperature: nil, rainMM: nil, probability: Int(pop), condition: "", durationHours: 6)) }
                        }
                        days[key] = day
                    }
                }
            }
        }
        let valid = days.values.filter { !$0.condition.isEmpty }.sorted { $0.date < $1.date }
        guard !valid.isEmpty else { throw SoraError.noForecast }
        return WeatherSnapshot(region: region, source: "JMA", issued: issued, fetched: now, days: valid, slots: slots.sorted { $0.date < $1.date })
    }
    static func codeDescription(_ code: String) -> String {
        let descriptions = ["100":"晴れ", "101":"晴れ時々くもり", "102":"晴れ一時雨", "103":"晴れ時々雨", "104":"晴れ一時雪", "110":"晴れ後くもり", "111":"晴れ後くもり", "112":"晴れ後一時雨", "113":"晴れ後時々雨", "114":"晴れ後雨", "115":"晴れ後一時雪", "116":"晴れ後時々雪", "117":"晴れ後雪", "200":"くもり", "201":"くもり時々晴れ", "202":"くもり一時雨", "203":"くもり時々雨", "204":"くもり一時雪", "205":"くもり時々雪", "206":"くもり一時雨か雪", "207":"くもり時々雨か雪", "210":"くもり後晴れ", "211":"くもり後晴れ", "212":"くもり後一時雨", "213":"くもり後時々雨", "214":"くもり後雨", "215":"くもり後一時雪", "216":"くもり後時々雪", "217":"くもり後雪", "300":"雨", "301":"雨時々晴れ", "302":"雨時々止む", "303":"雨時々雪", "308":"雨で暴風", "311":"雨後晴れ", "313":"雨後くもり", "314":"雨後雪", "400":"雪", "401":"雪時々晴れ", "402":"雪時々止む", "403":"雪時々雨", "406":"風雪強い", "411":"雪後晴れ", "413":"雪後くもり", "414":"雪後雨"]
        return descriptions[code] ?? (code.isEmpty ? "" : "天気コード \(code)")
    }
    public static func warnings(_ data: Data, office: String) throws -> (Date, [DisasterItem]) {
        struct Root: Decodable { let reportDatetime: String; let headlineText: String?; let areaTypes: [AreaType] }
        struct AreaType: Decodable { let areas: [WarningArea] }
        struct WarningArea: Decodable { let code: String; let warnings: [Warning] }
        struct Warning: Decodable { let code: String; let status: String }
        let root = try JSONDecoder().decode(Root.self, from: data)
        guard let issued = JapanTime.iso(root.reportDatetime) else { throw SoraError.invalidData }
        // Prefecture summary only; display geographic scope. Cancellations never become alerts.
        let active = root.areaTypes.flatMap(\.areas).filter { $0.code == office }.flatMap(\.warnings).filter { ["発表", "継続"].contains($0.status) }
        return (issued, active.map { w in DisasterItem(id: "\(office)-\(w.code)", title: "JMA \(warningName(w.code)) · \(w.status)", detail: root.headlineText ?? "", issued: issued) })
    }
    static func warningName(_ code: String) -> String {
        let names = ["02":"暴風雪警報", "03":"大雨警報", "04":"洪水警報", "05":"暴風警報", "06":"大雪警報", "07":"波浪警報", "08":"高潮警報", "10":"大雨注意報", "12":"大雪注意報", "13":"風雪注意報", "14":"雷注意報", "15":"強風注意報", "16":"波浪注意報", "17":"融雪注意報", "18":"洪水注意報", "19":"高潮注意報", "20":"濃霧注意報", "21":"乾燥注意報", "22":"なだれ注意報", "23":"低温注意報", "24":"霜注意報", "25":"着氷注意報", "26":"着雪注意報", "32":"暴風雪特別警報", "33":"大雨特別警報", "35":"暴風特別警報", "36":"大雪特別警報", "37":"波浪特別警報", "38":"高潮特別警報"]
        return names[code] ?? "コード \(code)"
    }
    public static func earthquakes(_ data: Data) throws -> [DisasterItem] {
        struct Quake: Decodable { let eid: String?; let rdt: String?; let at: String?; let ttl: String?; let anm: String?; let mag: String?; let maxi: String?; let ift: String? }
        let list = try JSONDecoder().decode([Quake].self, from: data)
        var seen = Set<String>()
        return list.sorted { ($0.rdt ?? "") > ($1.rdt ?? "") }.compactMap { q in
            guard let id = q.eid, let issued = q.rdt.flatMap(JapanTime.iso), seen.insert(id).inserted else { return nil }
            guard q.ift != "取消" else { return nil }
            return DisasterItem(id: id, title: q.anm ?? q.ttl ?? "JMA", detail: "M \(q.mag ?? "—") · 最大震度 \(q.maxi ?? "—") · \(q.at ?? "")", issued: issued)
        }
    }
}
