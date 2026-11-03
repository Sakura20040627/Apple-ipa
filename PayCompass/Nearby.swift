import SwiftUI
import Combine
import CoreLocation
import MapKit

struct NearbyPlace: Identifiable {
    let item: MKMapItem
    let distance: Double
    var id: String { "\(item.name ?? "")|\(item.placemark.coordinate.latitude)|\(item.placemark.coordinate.longitude)" }
    var name: String { item.name ?? L.t("名称不明", "未命名店鋪") }
    var address: String { [item.placemark.locality, item.placemark.thoroughfare, item.placemark.subThoroughfare].compactMap { $0 }.joined(separator: " ") }
    var distanceLabel: String { distance < 1000 ? "\(Int(distance)) m" : String(format: "%.1f km", distance / 1000) }
    var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }
}
@MainActor final class NearbyStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var places: [NearbyPlace] = []
    @Published var location: CLLocation?
    @Published var loading = false
    @Published var message: String?
    @Published var denied = false
    private let manager = CLLocationManager()
    private var generation = UUID()
    private var lastQuery = ""
    private var lastCategory = "すべて"
    private var searchTask: Task<Void, Never>?
    private var locationTimeout: Task<Void, Never>?
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func refresh(query: String = "", category: String = "すべて") {
        lastQuery = query; lastCategory = category; message = nil; denied = false
        guard CLLocationManager.locationServicesEnabled() else {
            denied = true; message = L.t("位置情報サービスがオフです。設定から有効にしてください。", "定位服務已關閉，請到系統設定開啟。"); return
        }
        switch manager.authorizationStatus {
        case .notDetermined: loading = true; manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            loading = true
            if let location, abs(location.timestamp.timeIntervalSinceNow) < 120 { search(from: location) }
            else {
                manager.requestLocation()
                locationTimeout?.cancel()
                locationTimeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    guard !Task.isCancelled, let self, self.loading, self.location == nil else { return }
                    self.loading = false; self.message = L.t("位置情報を取得できません。もう一度お試しください。", "暫時無法取得位置，請重試。")
                }
            }
        case .denied, .restricted:
            loading = false; denied = true; message = L.t("位置情報の利用が許可されていません。設定で「使用中のみ」を選択してください。", "尚未允許定位。請在設定中選擇「使用 App 期間」。")
        @unknown default: loading = false; message = L.t("位置情報を利用できません。", "無法使用定位服務。")
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.loading { self.refresh(query: self.lastQuery, category: self.lastCategory) }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, let location = locations.last else { return }
            self.locationTimeout?.cancel(); self.location = location; self.search(from: location)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.locationTimeout?.cancel(); self?.loading = false
            self?.message = L.t("位置情報を取得できませんでした。電波と権限を確認して再試行してください。", "無法取得位置，請確認訊號與權限後重試。")
        }
    }
    private func search(from location: CLLocation) {
        searchTask?.cancel()
        let token = UUID(); generation = token
        let query = lastQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = lastCategory
        loading = true
        searchTask = Task {
            var found: [NearbyPlace] = []
            var failures = 0
            let queries = query.isEmpty ? (category == "すべて" ? ["コンビニ", "スーパー", "レストラン", "ドラッグストア", "カフェ"] : [category]) : [query]
            for text in queries {
                if Task.isCancelled { return }
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = text
                request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 4000, longitudinalMeters: 4000)
                request.resultTypes = .pointOfInterest
                do {
                    let response = try await MKLocalSearch(request: request).start()
                    for item in response.mapItems {
                        let position = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                        let distance = location.distance(from: position)
                        if distance <= 3000 { found.append(NearbyPlace(item: item, distance: distance)) }
                    }
                } catch { failures += 1 }
            }
            guard !Task.isCancelled, token == generation else { return }
            var seen = Set<String>()
            places = found.sorted { $0.distance < $1.distance }.filter { seen.insert($0.id).inserted }
            loading = false
            if places.isEmpty { message = failures == queries.count ? L.t("地図検索に失敗しました。ネット接続を確認してください。", "地圖搜尋失敗，請檢查網路連線。") : L.t("約3km以内に結果がありません。別の店名やカテゴリで検索してください。", "約 3 公里內沒有結果，請換個店名或分類搜尋。") }
            else if failures > 0 { message = L.t("一部カテゴリの検索に失敗しました。結果は完全ではありません。", "部分分類搜尋失敗，結果可能不完整。") }
        }
    }
    func matchedMerchant(_ place: NearbyPlace, in merchants: [Merchant]) -> Merchant? {
        let name = place.name.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
        return merchants.filter { $0.latitude == nil }.first { m in
            let variants = [m.name] + (m.aliases ?? "").split(separator: " ").map(String.init)
            return variants.contains { term in
                let normalized = term.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
                return normalized.count >= 3 && name.contains(normalized)
            }
        }
    }
    func savedMerchant(_ place: NearbyPlace, in merchants: [Merchant]) -> Merchant? {
        merchants.first { m in
            guard let lat = m.latitude, let lon = m.longitude else { return false }
            return abs(lat - place.coordinate.latitude) < 0.0001 && abs(lon - place.coordinate.longitude) < 0.0001 && m.name == place.name
        }
    }
    func merchant(for place: NearbyPlace, in merchants: [Merchant]) -> Merchant {
        if let saved = savedMerchant(place, in: merchants) { return saved }
        let match = matchedMerchant(place, in: merchants)
        return Merchant(name: place.name, category: match?.category ?? "その他", key: match?.key ?? "general", favorite: false, aliases: match?.aliases, icon: match?.icon, color: match?.color, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, address: place.address)
    }
}
