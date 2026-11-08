import SwiftUI
import CoreLocation
import Combine

@MainActor final class WeatherModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: WeatherSnapshot?
    @Published var safety = WeatherService.Safety()
    @Published var loading = false
    @Published var cached = false
    @Published var fallback = false
    @Published var notice = ""
    @Published var notificationError = ""
    @Published var rain: [RainPoint] = []
    private var rainFetched: Date?
    @Published var notificationAllowed = false
    @Published var region: Region
    private let location = CLLocationManager()
    private var generation = UUID()
    private var locating = false
    private var lastRefresh: Date?
    private var snapshots: [String: WeatherSnapshot] = [:]
    init(initialRegion: Region? = nil) {
        region = initialRegion ?? Region.supported.first { $0.id == UserDefaults.standard.string(forKey: "region") } ?? .osaka
        super.init(); location.delegate = self; location.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    var japanese: Bool { AppLanguage.code == "ja" }
    func text(_ zh: String, _ ja: String) -> String { japanese ? ja : zh }
    func select(_ next: Region) async {
        guard next.id != region.id else { return }
        if let weather { snapshots[region.id] = weather }
        generation = UUID(); loading = false; region = next; weather = snapshots[next.id]; safety = .init(); rain = []; rainFetched = nil; lastRefresh = nil
        UserDefaults.standard.set(next.id, forKey: "region"); await RainNotifications.shared.cancel(); await refresh()
    }
    func refresh() async {
        // Throttle rapid pull-to-refresh. Region changes reset this gate.
        if loading || lastRefresh.map({ Date().timeIntervalSince($0) < 30 }) == true { return }
        loading = true; let token = generation; let selected = region
        notificationAllowed = await RainNotifications.shared.permission()
        if weather == nil {
            let saved = await WeatherService.shared.cached(selected)
            guard token == generation else { return }
            weather = saved; cached = saved != nil
        }
        async let result = WeatherService.shared.refresh(selected) { [weak self] value in
            await self?.publishPrimary(value, token: token)
        }
        async let info = WeatherService.shared.safety(region: selected)
        let r = await result
        guard token == generation else { return }
        weather = r.weather; cached = r.cached; fallback = r.yahooFailed
        let s = await info
        guard token == generation else { return }
        safety = s
        let key = UserDefaults.standard.string(forKey: "yahooClientID") ?? ""
        let nextRain = (try? await WeatherService.shared.rain(region: selected, clientID: key)) ?? []
        guard token == generation else { return }
        rain = nextRain
        rainFetched = rain.isEmpty ? nil : Date()
        let nextError = await RainNotifications.shared.reconcile(region: selected, snapshot: r.cached ? nil : r.weather, points: rain, fetched: rainFetched, enabled: UserDefaults.standard.bool(forKey: "rainEnabled") && (UserDefaults.standard.string(forKey: "region") ?? "osaka") == selected.id, japanese: japanese) ?? ""
        guard token == generation else { return }
        notificationError = nextError; loading = false; lastRefresh = Date()
    }
    private func publishPrimary(_ value: WeatherSnapshot, token: UUID) {
        guard token == generation else { return }
        weather = value; cached = false
    }
    func updateReminders() async {
        notificationAllowed = await RainNotifications.shared.permission()
        notificationError = await RainNotifications.shared.reconcile(region: region, snapshot: cached ? nil : weather, points: rain, fetched: rainFetched, enabled: UserDefaults.standard.bool(forKey: "rainEnabled"), japanese: japanese) ?? ""
        RainNotifications.shared.scheduleBackground()
    }
    func locate() {
        locating = true; notice = text("正在定位…", "現在地を確認中…")
        switch location.authorizationStatus {
        case .notDetermined: location.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: location.requestLocation()
        default: locating = false; notice = text("定位未授权，使用所选城市（默认大阪）", "位置情報は未許可です。選択した都市を表示します")
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if locating && [.authorizedAlways, .authorizedWhenInUse].contains(location.authorizationStatus) { location.requestLocation() }
            else if locating && [.denied, .restricted].contains(location.authorizationStatus) { locating = false; notice = text("定位未授权，保留所选城市", "位置情報は未許可です。都市を選択してください") }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last, fix.horizontalAccuracy >= 0, fix.horizontalAccuracy < 10_000, abs(fix.timestamp.timeIntervalSinceNow) < 120 else { return }
        let lat = fix.coordinate.latitude; let lon = fix.coordinate.longitude
        Task { @MainActor in
            locating = false
            guard let nearest = Region.nearest(latitude: lat, longitude: lon) else { notice = text("当前位置尚未覆盖，保留所选城市。可手动选择六个城市。", "現在地は対象外です。対応する6都市から選択できます。"); return }
            notice = text("已定位至附近预报区：\(nearest.name)（非精确地址预报）", "最寄りの予報区：\(nearest.name)（地点の実況ではありません）")
            loading = false; await select(nearest)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in locating = false; notice = text("定位失败，保留所选城市", "現在地を取得できません。選択した都市を表示します") }
    }
}
