import SwiftUI
import HexPickCore

@main
struct HexPickApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
                .tint(Theme.blue)
                .foregroundStyle(Theme.text)
                .preferredColorScheme(store.theme == "system" ? nil : (store.theme == "light" ? .light : .dark))
                .task { await store.start() }
        }
    }
}
