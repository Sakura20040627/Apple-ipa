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
    func refresh(_ region: Region) async -> Result {
        let now = Date()
        if let last = refreshes[region.id], now.timeIntervalSince(last) < 300, let value = memory[region.id] { return Result(weather: value, cached: false, yahooFailed: value.source == "JMA") }
        do {
            let htmlData = try await data(region.yahooURL)
            guard let html = String(data: htmlData, encoding: .utf8) else { throw SoraError.invalidData }
            let forecast = try YahooParser.forecast(html, region: region, now: now)
            guard !forecast.stale(at: now) else { throw SoraError.noForecast }
            var slots: [ForecastSlot] = forecast.slots
            if let pinData = try? await data(region.pinpointURL), let pin = String(data: pinData, encoding: .utf8), let (issued, parsed) = try? YahooParser.pinpoint(pin), abs(now.timeIntervalSince(issued)) <= 6*3600 { slots.append(contentsOf: parsed); slots.sort { $0.date < $1.date } }
            let value = WeatherSnapshot(region: region, source: forecast.source, issued: forecast.issued, fetched: now, days: forecast.days, slots: slots)
            save(value); return Result(weather: value, cached: false, yahooFailed: false)
        } catch is CancellationError { return Result(weather: cached(region), cached: true, yahooFailed: false) }
        catch {
            do {
                let value = try JMAParser.forecast(try await data(URL(string: "https://www.jma.go.jp/bosai/forecast/data/forecast/\(region.office).json")!), region: region, now: now)
                guard !value.stale(at: now) else { throw SoraError.noForecast }
                save(value); return Result(weather: value, cached: false, yahooFailed: true)
            } catch { return Result(weather: cached(region), cached: true, yahooFailed: true) }
        }
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
