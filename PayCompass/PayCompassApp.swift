import SwiftUI
@main struct PayCompassApp: App {
    @StateObject private var store = Store()
    var body: some Scene { WindowGroup { RootView().environmentObject(store) } }
}
