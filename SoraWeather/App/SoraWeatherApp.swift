import SwiftUI

@main struct SoraWeatherApp: App {
    @StateObject private var model = WeatherModel(locationCoordinatorOnly: true)
    private var language: String { AppLanguage.code }
    @AppStorage("autoLocation") private var autoLocation = true
    @Environment(\.scenePhase) private var phase
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reset") {
            for key in ["savedCities.v1", "selectedCityID", "selectedRegion.v1", "region"] { UserDefaults.standard.removeObject(forKey: key) }
        }
        #endif
        RainNotifications.shared.install()
    }
    var body: some Scene {
        WindowGroup {
            WeatherView(model: model)
                .environment(\.locale, Locale(identifier: language))
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-cities") {
                        let store = CityStore.shared
                        for region in Region.supported.dropFirst().prefix(2) { store.add(region) }
                        store.select(CityPersistence.locationID)
                    }
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-offline") { return }
                    #endif
                    if autoLocation { model.locate() }
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(600)) } catch { break }
                        if phase == .active { NotificationCenter.default.post(name: Notification.Name("SoraWeatherRefresh"), object: nil) }
                    }
                }
                .onChange(of: phase) { _, value in
                    
                    if value == .background { RainNotifications.shared.scheduleBackground() }
                }
        }
        .backgroundTask(.appRefresh(RainNotifications.backgroundID)) { await RainNotifications.shared.backgroundRefresh() }
    }
}
