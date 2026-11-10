import SwiftUI
import Observation
import HexPickGuides

@MainActor @Observable
final class GuideStore {
    var library: GuideLibrary?
    var error: String?
    var loading = false
    func load() async {
        guard library == nil, !loading else { return }
        loading = true; error = nil; defer { loading = false }
        do { library = try await Task.detached(priority: .utility) { try GuideLibrary.bundled() }.value }
        catch { self.error = error.localizedDescription }
    }
    var guides: [BuildGuide] { library?.guides ?? [] }
    func item(id: String) -> GuideItem? { library?.context.items[id] }
}
extension GuideAugment {
    func resource(version: String) -> ResourceIconRequest {
        ResourceIconRequest(kind: .augment, id: id, name: name, rarity: rarity, version: version, url: iconURL.flatMap(URL.init(string:)))
    }
}
extension GuideItem {
    func resource(version: String) -> ResourceIconRequest {
        ResourceIconRequest(kind: .item, id: id, name: name, rarity: "gold", version: version, url: iconURL.flatMap(URL.init(string:)))
    }
}
struct EquipmentIcon: View {
    @Environment(GuideStore.self) private var guides
    let id: String
    let name: String
    let version: String
    var body: some View {
        ResourceIcon(request: guides.item(id: id)?.resource(version: version) ?? ResourceIconRequest(kind: .item, id: id, name: name, rarity: "gold", version: version, url: nil))
    }
}
