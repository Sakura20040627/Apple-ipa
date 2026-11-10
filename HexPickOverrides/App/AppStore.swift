import SwiftUI
import Observation
import HexPickCore

@MainActor @Observable
final class AppStore {
    var dataset: Dataset?
    var updating = false
    var status = "正在载入离线数据"
    var error: String?
    var band = ""
    var theme: String { didSet { UserDefaults.standard.set(theme, forKey: "theme") } }
    var favoriteHeroes: Set<String> { didSet { save(favoriteHeroes, key: "favoriteHeroes") } }
    var favoriteAugments: Set<String> { didSet { save(favoriteAugments, key: "favoriteAugments") } }
    var recent: [String] { didSet { UserDefaults.standard.set(recent, forKey: "recent") } }
    private let repository: DataRepository
    private var started = false
    init() {
        let defaults = UserDefaults.standard
        theme = defaults.string(forKey: "theme") ?? "dark"
        favoriteHeroes = Set(defaults.stringArray(forKey: "favoriteHeroes") ?? [])
        favoriteAugments = Set(defaults.stringArray(forKey: "favoriteAugments") ?? [])
        recent = defaults.stringArray(forKey: "recent") ?? []
        let root = URL.applicationSupportDirectory.appendingPathComponent("HexPickData", isDirectory: true)
        repository = DataRepository(root: root)
    }
    var heroes: [String: Hero] { dataset?.heroTable(band: band) ?? [:] }
    var combinations: [String: [String: Stat]] { dataset?.comboTable(band: band) ?? [:] }
    var augments: [String: Augment] { dataset?.augments ?? [:] }
    var orderedHeroes: [String] {
        heroes.keys.sorted {
            let lhs = heroes[$0]?.rank ?? Int.max, rhs = heroes[$1]?.rank ?? Int.max
            return lhs == rhs ? $0 < $1 : lhs < rhs
        }
    }
    func start() async {
        guard !started else { return }; started = true
        do { dataset = try await repository.cached(); status = "离线数据已就绪" }
        catch { self.error = error.localizedDescription }
        await update()
    }
    func update() async {
        guard !updating else { return }; updating = true; defer { updating = false }
        error = nil
        do {
            let next = try await repository.update()
            dataset = next
            if next.bands[band] == nil { band = "" }
            status = "已检查，当前数据为最新快照"
        } catch {
            status = dataset == nil ? "暂时无法载入数据" : "更新失败，继续使用有效离线数据"
            self.error = error.localizedDescription
        }
    }
    func clearCache() async {
        guard !updating else { return }; updating = true; defer { updating = false }
        do { dataset = try await repository.clear(); band = ""; status = "已清除下载缓存，使用内置真实数据"; error = nil }
        catch { self.error = error.localizedDescription }
    }
    func viewed(_ id: String) { recent.removeAll { $0 == id }; recent.insert(id, at: 0); recent = Array(recent.prefix(12)) }
    func toggleHero(_ id: String) { if favoriteHeroes.contains(id) { favoriteHeroes.remove(id) } else { favoriteHeroes.insert(id) } }
    func toggleAugment(_ id: String) { if favoriteAugments.contains(id) { favoriteAugments.remove(id) } else { favoriteAugments.insert(id) } }
    private func save(_ values: Set<String>, key: String) { UserDefaults.standard.set(Array(values), forKey: key) }
    func recommendations(heroID: String, ids: [String]? = nil) -> [Recommendation] {
        guard let hero = heroes[heroID] else { return [] }
        let table = combinations[heroID] ?? [:]
        return RecommendationEngine.rank(ids: ids ?? Array(table.keys), hero: hero, stats: table)
    }
}
