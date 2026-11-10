import SwiftUI
import HexPickCore

@main
struct HexPickApp: App {
    @State private var store = AppStore()
    @State private var guides = GuideStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(guides)
                .tint(Theme.blue)
                .foregroundStyle(Theme.text)
                .preferredColorScheme(store.theme == "system" ? nil : (store.theme == "light" ? .light : .dark))
                .task { await store.start() }
                .task { await guides.load() }
        }
    }
}
