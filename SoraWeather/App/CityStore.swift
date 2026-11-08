import SwiftUI
import MapKit

@MainActor final class CityStore: ObservableObject {
    static let shared = CityStore()
    @Published private(set) var selectionFeedback = 0
    @Published private(set) var mutationFeedback = 0
    @Published private(set) var cities: [SavedCity]
    @Published var selectedID: String { didSet { defaults.set(selectedID, forKey: "selectedCityID") } }
    @Published private(set) var catalog: [Region] = Region.supported
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoded = defaults.data(forKey: "savedCities.v1").flatMap { try? JSONDecoder().decode([SavedCity].self, from: $0) } ?? []
        let initial = CityPersistence.normalized(decoded)
        cities = initial
        let stored = defaults.string(forKey: "selectedCityID") ?? CityPersistence.locationID
        selectedID = initial.contains(where: { $0.id == stored }) ? stored : CityPersistence.locationID
        Task { @MainActor [weak self] in
            let loaded: [Region]? = await Task.detached(priority: .utility) {
                guard let url = Bundle.main.url(forResource: "ForecastRegions", withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode([Region].self, from: data)
            }.value
            if let loaded, !loaded.isEmpty { self?.catalog = loaded }
        }
    }
    var selected: SavedCity { cities.first { $0.id == selectedID } ?? cities[0] }
    func select(_ id: String, haptic: Bool = true) {
        guard let city = cities.first(where: { $0.id == id }) else { return }
        if selectedID != id { selectedID = id; if haptic { selectionFeedback += 1 } }
        defaults.set(city.region.id, forKey: "region")
        defaults.set(try? JSONEncoder().encode(city.region), forKey: "selectedRegion.v1")
    }
    func add(_ region: Region) {
        if let existing = cities.first(where: { !$0.isLocation && $0.region.id == region.id }) { select(existing.id); return }
        let item = SavedCity(id: UUID().uuidString, region: region)
        cities.append(item); save(); select(item.id, haptic: false); mutationFeedback += 1
    }
    func remove(_ offsets: IndexSet) {
        let ids = Set(offsets.compactMap { cities.indices.contains($0) && !cities[$0].isLocation ? cities[$0].id : nil })
        guard !ids.isEmpty else { return }
        cities = CityPersistence.deleting(ids, from: cities)
        if !cities.contains(where: { $0.id == selectedID }) { select(CityPersistence.locationID, haptic: false) }
        save(); mutationFeedback += 1
    }
    func move(_ offsets: IndexSet, to destination: Int) {
        let allowed = IndexSet(offsets.filter { cities.indices.contains($0) && !cities[$0].isLocation })
        guard !allowed.isEmpty else { return }
        cities.move(fromOffsets: allowed, toOffset: max(1, min(destination, cities.count))); save()
    }
    func updateRegion(_ region: Region, for id: String) {
        guard let i = cities.firstIndex(where: { $0.id == id }), cities[i].region != region else { return }
        cities[i].region = region; save()
        if selectedID == id { select(id) }
    }
    func nearby(latitude: Double, longitude: Double) -> Region? {
        let point = CLLocation(latitude: latitude, longitude: longitude)
        guard let candidate = catalog.min(by: {
            point.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) < point.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }), point.distance(from: CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)) <= 45_000 else { return nil }
        return candidate
    }
    func matches(_ query: String) -> [Region] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "东京", with: "東京").replacingOccurrences(of: "神户", with: "神戸").replacingOccurrences(of: "福冈", with: "福岡")
        guard !q.isEmpty else { return [] }
        return catalog.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }
    private func save() { if let data = try? JSONEncoder().encode(cities) { defaults.set(data, forKey: "savedCities.v1") } }
}

@MainActor final class WeatherPagePool {
    private var models: [String: WeatherModel] = [:]
    func model(for city: SavedCity) -> WeatherModel {
        if let existing = models[city.id], existing.region == city.region { return existing }
        let value = WeatherModel(initialRegion: city.region); models[city.id] = value; return value
    }
    func retainedIDs(cities: [SavedCity], selected: String) -> Set<String> {
        guard let index = cities.firstIndex(where: { $0.id == selected }) else { return [] }
        return Set(cities.indices.filter { abs($0-index) <= 1 }.map { cities[$0].id })
    }
    func prune(cities: [SavedCity], selected: String) {
        let keep = retainedIDs(cities: cities, selected: selected); models = models.filter { keep.contains($0.key) }
    }
}
