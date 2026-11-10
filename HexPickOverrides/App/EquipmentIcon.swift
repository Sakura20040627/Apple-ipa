import SwiftUI
struct EquipmentIcon: View {
    let id: String
    let name: String
    let version: String
    private struct Entry: Decodable { let name: String; let url: String }
    private static let entries: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "EquipmentIcons", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }()
    var body: some View {
        ResourceIcon(request: ResourceIconRequest(kind: .item, id: id, name: name, rarity: "gold", version: version, url: Self.entries[id].flatMap { URL(string: $0.url) }))
    }
}
