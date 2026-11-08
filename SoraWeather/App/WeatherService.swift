import Foundation

actor WeatherService {
    static let shared = WeatherService()
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 25
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()
    private var memory: [String: WeatherSnapshot] = [:]
    private var refreshes: [String: Date] = [:]
    func data(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url); request.setValue("SoraWeather/1.0 (personal weather reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw SoraError.http((response as? HTTPURLResponse)?.statusCode ?? 0) }
        guard data.count <= 5_000_000 else { throw SoraError.tooLarge }; return data
    }
    private func cacheURL(_ region: Region) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("weather-\(region.id).json")
    }
    func cached(_ region: Region) -> WeatherSnapshot? {
        if let value = memory[region.id] { return value }
        guard let data = try? Data(contentsOf: cacheURL(region)), let value = try? JSONDecoder().decode(WeatherSnapshot.self, from: data), value.region == region else { return nil }
        return value
    }
    struct Result: Sendable { let weather: WeatherSnapshot?; let cached: Bool; let yahooFailed: Bool }
    func refresh(_ region: Region, publish: (@Sendable (WeatherSnapshot) async -> Void)? = nil) async -> Result {
        let now = Date()
        if let last = refreshes[region.id], now.timeIntervalSince(last) < 300, let value = memory[region.id] {
            return Result(weather: value, cached: false, yahooFailed: UserDefaults.standard.bool(forKey: "yahooUnavailable." + region.id))
        }
        async let primaryResult = loadJMA(region, now: now)
        async let supplementResult = loadYahoo(region, now: now)
        let primary = await primaryResult
        if let primary { save(primary); await publish?(primary) }
        let supplement = await supplementResult
        let unavailable = supplement == nil
        UserDefaults.standard.set(unavailable, forKey: "yahooUnavailable." + region.id)
        guard let primary else {
            // Retain the last successful primary snapshot; never replace it with an empty response.
            return Result(weather: cached(region), cached: true, yahooFailed: unavailable)
        }
        let value = WeatherMerge.combine(primary: primary, supplement: supplement)
        save(value)
        return Result(weather: value, cached: false, yahooFailed: unavailable)
    }
    private func loadJMA(_ region: Region, now: Date) async -> WeatherSnapshot? {
        guard let bytes = try? await data(URL(string: "https://www.jma.go.jp/bosai/forecast/data/forecast/\(region.office).json")!),
              let value = try? JMAParser.forecast(bytes, region: region, now: now), !value.days.isEmpty else { return nil }
        return value.stale(at: now) ? nil : value
    }
    private func loadYahoo(_ region: Region, now: Date) async -> WeatherSnapshot? {
        var forecast: WeatherSnapshot?
        var slots: [ForecastSlot] = []
        if let bytes = try? await data(region.yahooURL), let html = String(data: bytes, encoding: .utf8), let value = YahooParser.resilientForecast(html, region: region, now: now), !value.stale(at: now) { forecast = value }
        if let bytes = try? await data(region.pinpointURL), let html = String(data: bytes, encoding: .utf8), let (issued, values) = YahooParser.resilientPinpoint(html), now.timeIntervalSince(issued) >= -600, now.timeIntervalSince(issued) <= 6*3600 { slots = values }
        guard forecast != nil || !slots.isEmpty else { return nil }
        return WeatherSnapshot(region: region, source: "Yahoo! JAPAN", issued: forecast?.issued ?? now, fetched: now, days: forecast?.days ?? [], slots: slots.isEmpty ? (forecast?.slots ?? []) : slots)
    }
    private func save(_ value: WeatherSnapshot) {
        memory[value.region.id] = value; refreshes[value.region.id] = Date()
        if let bytes = try? JSONEncoder().encode(value) { try? bytes.write(to: cacheURL(value.region), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }
    func rain(region: Region, clientID: String) async throws -> [RainPoint] {
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var url = URLComponents(string: "https://map.yahooapis.jp/weather/V1/place")!
        url.queryItems = [URLQueryItem(name: "appid", value: clientID), URLQueryItem(name: "coordinates", value: "\(region.longitude),\(region.latitude)"), URLQueryItem(name: "output", value: "json"), URLQueryItem(name: "interval", value: "10")]
        return try YahooParser.rain(await data(url.url!))
    }
    struct Safety: Sendable {
        var warnings: [DisasterItem] = []; var quakes: [DisasterItem] = []
        var warningsIssued: Date?; var warningsFetched: Date?; var quakesFetched: Date?
    }
    func safety(region: Region) async -> Safety {
        var result = Safety()
        if let bytes = try? await data(URL(string: "https://www.jma.go.jp/bosai/warning/data/warning/\(region.office).json")!), let (issued, warnings) = try? JMAParser.warnings(bytes, office: region.office) { result.warnings = warnings; result.warningsIssued = issued; result.warningsFetched = Date() }
        if let bytes = try? await data(URL(string: "https://www.jma.go.jp/bosai/quake/data/list.json")!), let quakes = try? JMAParser.earthquakes(bytes) { result.quakes = Array(quakes.prefix(10)); result.quakesFetched = Date() }
        return result
    }
}
