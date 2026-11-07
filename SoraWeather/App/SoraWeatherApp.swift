import SwiftUI

@main struct SoraWeatherApp: App {
    @StateObject private var model = WeatherModel()
    @AppStorage("language") private var language = "zh-Hans"
    @AppStorage("autoLocation") private var autoLocation = true
    @Environment(\.scenePhase) private var phase
    init() { RainNotifications.shared.install() }
    var body: some Scene {
        WindowGroup {
            WeatherView(model: model)
                .environment(\.locale, Locale(identifier: language))
                .task {
                    if autoLocation { model.locate() }; await model.refresh()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(600)) } catch { break }
                        if phase == .active { await model.refresh() }
                    }
                }
                .onChange(of: phase) { _, value in
                    if value == .active { Task { await model.refresh(); await model.updateReminders() } }
                    if value == .background { RainNotifications.shared.scheduleBackground() }
                }
        }
        .backgroundTask(.appRefresh(RainNotifications.backgroundID)) { await RainNotifications.shared.backgroundRefresh() }
    }
}
